#include "backend.h"

#include <QAudioDeviceInfo>
#include <QAudioInput>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QThread>
#include <QFile>
#include <QTimer>
#include <QtDBus>
#include <QtMath>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <libintl.h>

namespace {

// gettext domain shared with the QML side (i18n.tr); bound in DeviceBackendPlugin::registerTypes
const char *const GETTEXT_DOMAIN = "devicetester.jimmy";

QString T(const char *msg)
{
    return QString::fromUtf8(dgettext(GETTEXT_DOMAIN, msg));
}

const QString NM_SERVICE = QStringLiteral("org.freedesktop.NetworkManager");
const QString NM_PATH = QStringLiteral("/org/freedesktop/NetworkManager");

QString readSysfs(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromUtf8(f.readAll()).trimmed();
}

const QString OFONO = QStringLiteral("org.ofono");

// Reads a D-Bus a{sv} dictionary (values as QVariant; arrays stay QDBusArgument)
QVariantMap readDict(const QDBusArgument &arg)
{
    QVariantMap map;
    arg.beginMap();
    while (!arg.atEnd()) {
        QString key;
        QDBusVariant value;
        arg.beginMapEntry();
        arg >> key >> value;
        arg.endMapEntry();
        map.insert(key, value.variant());
    }
    arg.endMap();
    return map;
}

QVariantMap ofonoProps(const QString &path, const QString &iface)
{
    QDBusInterface i(OFONO, path, iface, QDBusConnection::systemBus());
    const QDBusMessage r = i.call("GetProperties");
    if (r.type() != QDBusMessage::ReplyMessage || r.arguments().isEmpty())
        return QVariantMap();
    return readDict(r.arguments().first().value<QDBusArgument>());
}

int kbOf(const QString &meminfo, const QString &key)
{
    for (const QString &line : meminfo.split('\n'))
        if (line.startsWith(key + ":"))
            return line.mid(key.size() + 1).trimmed().split(' ').first().toInt();
    return 0;
}

double toDb(double linear)
{
    return linear > 1e-9 ? 20.0 * std::log10(linear) : -120.0;
}

} // namespace

Backend::Backend(QObject *parent) : QObject(parent) {}

Backend::~Backend()
{
    if (m_input)
        m_input->stop();
}

// ---------------------------------------------------------------- Rapport

QString Backend::saveReport(const QString &text) const
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation));
    if (!dir.mkpath("."))
        return QString();
    const QString path = dir.filePath(
        QStringLiteral("devicetester-%1.txt").arg(QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss")));
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return QString();
    f.write(text.toUtf8());
    return path;
}

// ---------------------------------------------------------------- Modem / SIM (oFono)

// Keys: ofono, modem, modemCount, modemName, imei, powered, online, simPresent, pin, simOperator,
//        regStatus, netName, tech, strength, attached, dataPowered, roaming, error
QVariantMap Backend::simInfo() const
{
    QVariantMap out;
    out["ofono"] = false;
    out["modem"] = false;
    out["simPresent"] = false;

    QDBusInterface mgr(OFONO, "/", "org.ofono.Manager", QDBusConnection::systemBus());
    if (!mgr.isValid()) {
        out["error"] = T("oFono unreachable (system D-Bus)");
        return out;
    }
    out["ofono"] = true;

    const QDBusMessage reply = mgr.call("GetModems");
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        out["error"] = T("GetModems failed");
        return out;
    }

    QList<QPair<QString, QVariantMap>> modems;
    const QDBusArgument arg = reply.arguments().first().value<QDBusArgument>();
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusObjectPath path;
        arg.beginStructure();
        arg >> path;
        const QVariantMap props = readDict(arg);
        arg.endStructure();
        modems.append({path.path(), props});
    }
    arg.endArray();

    out["modemCount"] = modems.size();
    if (modems.isEmpty()) {
        out["error"] = T("No modem detected by oFono");
        return out;
    }

    // Prefer the modem that has a SIM
    int pick = 0;
    for (int i = 0; i < modems.size(); ++i) {
        const QStringList ifaces = qdbus_cast<QStringList>(modems[i].second.value("Interfaces"));
        if (ifaces.contains("org.ofono.SimManager")
            && ofonoProps(modems[i].first, "org.ofono.SimManager").value("Present").toBool()) {
            pick = i;
            break;
        }
    }
    const QString path = modems[pick].first;
    const QVariantMap &mp = modems[pick].second;
    const QStringList ifaces = qdbus_cast<QStringList>(mp.value("Interfaces"));

    out["modem"] = true;
    QString name = (mp.value("Manufacturer").toString() + " " + mp.value("Model").toString()).trimmed();
    out["modemName"] = name.isEmpty() ? mp.value("Name").toString() : name;
    out["imei"] = mp.value("Serial").toString();
    out["powered"] = mp.value("Powered").toBool();
    out["online"] = mp.value("Online").toBool();

    if (ifaces.contains("org.ofono.SimManager")) {
        const QVariantMap sp = ofonoProps(path, "org.ofono.SimManager");
        out["simPresent"] = sp.value("Present").toBool();
        out["pin"] = sp.value("PinRequired", "none").toString();
        out["simOperator"] = sp.value("ServiceProviderName").toString();
    }
    if (ifaces.contains("org.ofono.NetworkRegistration")) {
        const QVariantMap np = ofonoProps(path, "org.ofono.NetworkRegistration");
        out["regStatus"] = np.value("Status").toString();
        out["netName"] = np.value("Name").toString();
        out["tech"] = np.value("Technology").toString();
        out["strength"] = np.value("Strength").toInt();
    }
    if (ifaces.contains("org.ofono.ConnectionManager")) {
        const QVariantMap cp = ofonoProps(path, "org.ofono.ConnectionManager");
        out["attached"] = cp.value("Attached").toBool();
        out["dataPowered"] = cp.value("Powered").toBool();
        out["roaming"] = cp.value("RoamingAllowed").toBool();
    }
    return out;
}

// ---------------------------------------------------------------- Appareil

QVariantMap Backend::deviceInfo() const
{
    QVariantMap out;
    QString model = readSysfs("/sys/firmware/devicetree/base/model");
    model.remove(QChar(0));
    out["model"] = model.trimmed();
    out["os"] = QSysInfo::prettyProductName();
    out["kernel"] = QSysInfo::kernelVersion();
    out["arch"] = QSysInfo::currentCpuArchitecture();
    out["hostname"] = QSysInfo::machineHostName();

    for (const QString &line : readSysfs("/etc/system-image/channel.ini").split('\n'))
        if (line.startsWith("channel:"))
            out["channel"] = line.mid(8).trimmed();

    out["cpuCores"] = QThread::idealThreadCount();
    out["cpuMaxMHz"] = readSysfs("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq").toInt() / 1000;
    out["cpuCurMHz"] = readSysfs("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq").toInt() / 1000;

    const QString mem = readSysfs("/proc/meminfo");
    out["memTotalMB"] = kbOf(mem, "MemTotal") / 1024;
    out["memAvailMB"] = kbOf(mem, "MemAvailable") / 1024;

    const QStorageInfo st(QStringLiteral("/home"));
    out["storageTotalMB"] = static_cast<qlonglong>(st.bytesTotal() / (1024 * 1024));
    out["storageFreeMB"] = static_cast<qlonglong>(st.bytesAvailable() / (1024 * 1024));
    return out;
}

int Backend::headsetState() const
{
    bool ok = false;
    const int v = readSysfs("/sys/class/switch/h2w/state").toInt(&ok);
    return ok ? v : -1;
}

// ---------------------------------------------------------------- Torche

bool Backend::setTorch(bool on) const
{
    const QString root = QStringLiteral("/sys/class/leds/");
    bool ok = false;
    const QStringList torches = QDir(root).entryList({QStringLiteral("led:torch_*")}, QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : torches) {
        int level = 0;
        if (on) {
            level = readSysfs(root + name + "/max_brightness").toInt() / 2;
            if (level <= 0)
                level = 100;
        }
        QFile f(root + name + "/brightness");
        if (f.open(QIODevice::WriteOnly)) {
            f.write(QByteArray::number(level));
            ok = true;
        }
    }
    QFile sw(root + "led:switch/brightness");
    if (sw.open(QIODevice::WriteOnly))
        sw.write(on ? "1" : "0");
    return ok;
}

// ---------------------------------------------------------------- Batterie

QVariantMap Backend::batteryInfo() const
{
    QVariantMap out;
    out["found"] = false;
    out["charger"] = false;

    const QString root = QStringLiteral("/sys/class/power_supply");
    const QStringList entries = QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : entries) {
        const QString base = root + "/" + name + "/";
        const QString type = readSysfs(base + "type");
        if (type == QLatin1String("Battery") && !out["found"].toBool()) {
            bool ok = false;
            const int capacity = readSysfs(base + "capacity").toInt(&ok);
            out["found"] = ok;
            out["name"] = name;
            out["capacity"] = ok ? capacity : -1;
            out["status"] = readSysfs(base + "status");
            out["health"] = readSysfs(base + "health");
            out["technology"] = readSysfs(base + "technology");
            const double uv = readSysfs(base + "voltage_now").toDouble();
            out["voltage"] = uv > 0 ? uv / 1e6 : 0.0;
            const QString temp = readSysfs(base + "temp");
            out["temperature"] = temp.isEmpty() ? QVariant() : QVariant(temp.toDouble() / 10.0);
        } else if (type != QLatin1String("Battery") && readSysfs(base + "online") == QLatin1String("1")) {
            out["charger"] = true;
            out["chargerType"] = type;
        }
    }
    return out;
}

// ---------------------------------------------------------------- Micro

void Backend::startMicTest(int durationMs)
{
    if (m_input) // test already running
        return;

    const QAudioDeviceInfo dev = QAudioDeviceInfo::defaultInputDevice();
    if (dev.isNull()) {
        emit micFinished(false, -120, -120, T("No audio input device"));
        return;
    }

    QAudioFormat fmt;
    fmt.setSampleRate(44100);
    fmt.setChannelCount(1);
    fmt.setSampleSize(16);
    fmt.setCodec("audio/pcm");
    fmt.setByteOrder(QAudioFormat::LittleEndian);
    fmt.setSampleType(QAudioFormat::SignedInt);
    if (!dev.isFormatSupported(fmt))
        fmt = dev.nearestFormat(fmt);
    m_format = fmt;

    m_data.clear();
    m_input = new QAudioInput(dev, fmt, this);
    m_io = m_input->start();
    if (!m_io) {
        const int err = m_input->error();
        m_input->deleteLater();
        m_input = nullptr;
        emit micFinished(false, -120, -120, T("Could not open the microphone (error %1)").arg(err));
        return;
    }
    connect(m_io, &QIODevice::readyRead, this, [this]() { m_data.append(m_io->readAll()); });
    QTimer::singleShot(durationMs, this, &Backend::finishMic);
}

void Backend::finishMic()
{
    if (!m_input)
        return;
    if (m_io)
        m_data.append(m_io->readAll());
    const int err = m_input->error();
    m_input->stop();
    m_input->deleteLater();
    m_input = nullptr;
    m_io = nullptr;

    const int bytes = m_format.sampleSize() / 8;
    if (m_data.isEmpty() || bytes <= 0) {
        emit micFinished(false, -120, -120,
                         err != QAudio::NoError ? T("Audio error %1").arg(err)
                                                : T("No data received from the microphone"));
        return;
    }

    const int count = m_data.size() / bytes;
    const char *p = m_data.constData();
    double sumSq = 0, peak = 0;
    for (int i = 0; i < count; ++i, p += bytes) {
        double v = 0;
        if (m_format.sampleType() == QAudioFormat::Float && bytes == 4) {
            float f;
            std::memcpy(&f, p, 4);
            v = f;
        } else if (m_format.sampleType() == QAudioFormat::UnSignedInt && bytes == 1) {
            v = (static_cast<quint8>(p[0]) - 128) / 128.0;
        } else if (bytes == 2) {
            qint16 s;
            std::memcpy(&s, p, 2);
            v = s / 32768.0;
        } else if (bytes == 4) {
            qint32 s;
            std::memcpy(&s, p, 4);
            v = s / 2147483648.0;
        } else {
            emit micFinished(false, -120, -120, T("Unsupported audio format (%1 bytes)").arg(bytes));
            return;
        }
        sumSq += v * v;
        peak = std::max(peak, std::abs(v));
    }
    const double rms = qSqrt(sumSq / count);
    emit micFinished(true, toDb(rms), toDb(peak),
                     T("%1 Hz, %2 samples").arg(m_format.sampleRate()).arg(count));
}

// ---------------------------------------------------------------- Wi-Fi

void Backend::startWifiScan()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    QDBusInterface nm(NM_SERVICE, NM_PATH, NM_SERVICE, bus);
    if (!nm.isValid()) {
        emit wifiFinished(false, {}, T("NetworkManager unreachable (system D-Bus)"));
        return;
    }
    if (!nm.property("WirelessEnabled").toBool()) {
        emit wifiFinished(false, {}, T("Wi-Fi is off"));
        return;
    }

    QDBusReply<QList<QDBusObjectPath>> devices = nm.call("GetDevices");
    if (!devices.isValid()) {
        emit wifiFinished(false, {}, T("GetDevices failed: %1").arg(devices.error().message()));
        return;
    }

    m_wifiDevicePath.clear();
    for (const QDBusObjectPath &path : devices.value()) {
        QDBusInterface dev(NM_SERVICE, path.path(), NM_SERVICE + ".Device", bus);
        if (dev.property("DeviceType").toUInt() == 2) { // NM_DEVICE_TYPE_WIFI
            m_wifiDevicePath = path.path();
            break;
        }
    }
    if (m_wifiDevicePath.isEmpty()) {
        emit wifiFinished(false, {}, T("No Wi-Fi interface"));
        return;
    }

    QDBusInterface wifi(NM_SERVICE, m_wifiDevicePath, NM_SERVICE + ".Device.Wireless", bus);
    // May be refused (scan too frequent): the cached results are read instead.
    wifi.call("RequestScan", QVariantMap());
    QTimer::singleShot(4000, this, &Backend::readAccessPoints);
}

void Backend::readAccessPoints()
{
    QDBusConnection bus = QDBusConnection::systemBus();
    QDBusInterface wifi(NM_SERVICE, m_wifiDevicePath, NM_SERVICE + ".Device.Wireless", bus);
    QDBusReply<QList<QDBusObjectPath>> aps = wifi.call("GetAllAccessPoints");
    if (!aps.isValid()) {
        emit wifiFinished(false, {}, T("Could not read the networks: %1").arg(aps.error().message()));
        return;
    }

    QMap<QString, QVariantMap> bySsid; // garde le meilleur signal par SSID
    for (const QDBusObjectPath &path : aps.value()) {
        QDBusInterface ap(NM_SERVICE, path.path(), NM_SERVICE + ".AccessPoint", bus);
        const QString ssid = QString::fromUtf8(ap.property("Ssid").toByteArray());
        const int strength = ap.property("Strength").toInt();
        if (ssid.isEmpty())
            continue;
        if (!bySsid.contains(ssid) || bySsid[ssid]["strength"].toInt() < strength) {
            QVariantMap m;
            m["ssid"] = ssid;
            m["strength"] = strength;
            m["frequency"] = ap.property("Frequency").toUInt();
            bySsid[ssid] = m;
        }
    }

    QList<QVariantMap> sorted = bySsid.values();
    std::sort(sorted.begin(), sorted.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a["strength"].toInt() > b["strength"].toInt();
    });
    QVariantList networks;
    for (const QVariantMap &m : sorted)
        networks << m;

    emit wifiFinished(true, networks, T("%1 network(s) visible").arg(networks.size()));
}
