#include "plugin.h"
#include "backend.h"

#include <QDir>
#include <QtQml>
#include <libintl.h>

void DeviceBackendPlugin::registerTypes(const char *uri)
{
    // Make i18n.tr() in QML (and T() in C++) use our catalog. Translations are installed in
    // <app dir>/share/locale, and this plugin lives in <app dir>/qml/DeviceBackend.
    const char *domain = "devicetester.jimmy";
    const QString localeDir = QDir(baseUrl().toLocalFile()).absoluteFilePath(QStringLiteral("../../share/locale"));
    bindtextdomain(domain, QDir::cleanPath(localeDir).toUtf8().constData());
    bind_textdomain_codeset(domain, "UTF-8");
    textdomain(domain);

    qmlRegisterType<Backend>(uri, 1, 0, "Backend");
}
