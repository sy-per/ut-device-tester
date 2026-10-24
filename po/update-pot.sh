#!/bin/bash
# Refresh the translation template from the sources and merge it into every .po file.
# Source strings are English: QML uses i18n.tr("..."), C++ uses T("...").
set -e
cd "$(dirname "$0")/.."
FILES=$(find qml backend -name '*.qml' -o -name '*.cpp' | sort)
xgettext -L JavaScript --from-code=UTF-8 --keyword=i18n.tr --keyword=T -o po/devicetester.jimmy.pot $FILES
for po in po/*.po; do msgmerge --update --backup=none "$po" po/devicetester.jimmy.pot; done
