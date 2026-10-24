#pragma once

#include <QAudioFormat>
#include <QByteArray>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class QAudioInput;
class QIODevice;

// Hardware access not exposed to QML: battery (sysfs), microphone (QAudioInput),
// Wi-Fi scan (NetworkManager over the system D-Bus), SIM/modem (oFono), torch and device info.
class Backend : public QObject
{
    Q_OBJECT

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    // { found, name, capacity (%), status, health, voltage (V), temperature (°C), charger (bool) }
    Q_INVOKABLE QVariantMap batteryInfo() const;

    // Records for `durationMs` ms then emits micFinished (levels in dBFS).
    Q_INVOKABLE void startMicTest(int durationMs = 3000);

    // Requests a scan and emits wifiFinished with [{ssid, strength, frequency}] sorted by signal.
    Q_INVOKABLE void startWifiScan();

    // Writes the report to ~/Documents/devicetester-<date>.txt; returns the path, or "" on failure.
    Q_INVOKABLE QString saveReport(const QString &text) const;

    // Turns the flashlight on/off through /sys/class/leds/led:torch_* (+ led:switch). Returns false if not writable.
    Q_INVOKABLE bool setTorch(bool on) const;

    // Modem / SIM / mobile network through oFono (system D-Bus). See keys in backend.cpp.
    Q_INVOKABLE QVariantMap simInfo() const;

    // { model, os, channel, kernel, arch, hostname, cpuCores, cpuMaxMHz, cpuCurMHz, memTotalMB, memAvailMB, storageTotalMB, storageFreeMB }
    Q_INVOKABLE QVariantMap deviceInfo() const;

    // Headset jack (/sys/class/switch/h2w/state): 0 nothing, 1 headset with mic, 2 headphones only, -1 unavailable.
    Q_INVOKABLE int headsetState() const;

signals:
    void micFinished(bool ok, double rmsDb, double peakDb, const QString &message);
    void wifiFinished(bool ok, const QVariantList &networks, const QString &message);

private:
    void finishMic();
    void readAccessPoints();

    QAudioInput *m_input = nullptr;
    QIODevice *m_io = nullptr;
    QByteArray m_data;
    QAudioFormat m_format;
    QString m_wifiDevicePath;
};
