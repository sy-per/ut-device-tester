# UT Device Tester — contexte de dev

App Ubuntu Touch (QML pur, Lomiri.Components 1.3, Qt 5.12+) qui teste le matériel du téléphone.
Cible : UT 24.04 / OnePlus 3T (voir `../OnePlus 3T Ubuntu Touch/`), cadre `ubuntu-sdk-20.04`.

## État (v0.1.0, 2026-10-24)
Compile (arm64) et tourne sur le OnePlus 3T (UT 24.04), sans erreur QML au lancement. Assistant guidé + accueil par catégories + résumé implémentés (maquette validée). Résultats des tests sur l'appareil pas encore tous relus.

## Déploiement (testé)
- `wsl --cd "<dossier>" -e bash ./build.sh` -> `dist/devicetester.jimmy_0.1.0_arm64.click` (Clickable refuse les chemins avec espaces : build sur copie ~/devicetester, WSL Debian, clickable via pipx, docker OK).
- Téléphone en mode USB `mtp_adb` (rebrancher le câble si RNDIS) : adb Windows = `OnePlus 3T Ubuntu Touch/tools/platform-tools/adb.exe`. Push dans /home/phablet puis `sudo -S click install --allow-unauthenticated --user=phablet <fichier>` (sudo = code de déverrouillage de l'utilisateur). Lancer : `XDG_RUNTIME_DIR=/run/user/32011 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus lomiri-app-launch devicetester.jimmy_devicetester_0.1.0`. Logs : `journalctl --user | grep aa-exec`.
- Pièges QML trouvés : `connectToBackend()` n'existe pas en QML (utiliser `Sensor.start()` + `connectedToBackend`) ; l'id `summary` entre en conflit avec `ListItemLayout.summary` ; icône suru `compass` absente (utiliser `location`).

## Build / install
```
cd "UT Device Tester"
clickable desktop          # test PC (capteurs/GPS absents)
clickable --ssh <ip>       # ou: clickable install  (USB, adb)
```
`clickable.yaml` : builder `cmake` (plugin C++). `manifest.json.in` -> manifest.json (architecture via CLICK_ARCH). `devicetester.apparmor` = template **unconfined** (accès Bluetooth/GPS/caméra sans policy groups ; à resserrer plus tard : camera, location, microphone, audio, networking, video).

## Architecture
- `qml/Main.qml` : tests (`buildTests()`, champs cat/manual/fullscreen/intro/props), file d'exécution (`startQueue/nextTest/startCurrent/record`), accueil par catégories (pastilles x/y), assistant plein écran (écran de consigne pour les tests `manual`, Oui/Non affiché par l'hôte pour les tests non visuels via `TestBase.showBar=false`), résumé (KO/ignorés, relancer les KO, copier, enregistrer via `Backend.saveReport` -> ~/Documents), dernier passage persisté en LocalStorage.
- `qml/TestBase.qml` : base des tests. API : `run()`, `cleanup()`, `pass/fail/skip/note/ask(question)`, timeout auto → fail. Un test = un fichier dans `qml/tests/`, chargé par Loader ; échec de chargement (module QML absent) → KO « Module QML indisponible ».
- Tests : Display, Touch (multi-touch 12 zones), Buttons (volume), Vibration (QtFeedback), Speaker (`assets/tone.wav`), Storage (LocalStorage), Network (XHR 204 + Lomiri.Connectivity optionnel), Bluetooth (BluetoothDiscoveryModel), GPS (PositionSource), Sensor générique (accéléro, gyro, magnéto, boussole, orientation, proximité, lumière, baromètre), Camera (par caméra détectée, capture auto), Torch.
- « Tests automatiques seulement » = ceux sans `manual`; « Assistant guidé » = tous; toucher une catégorie = ses tests.

## Plugin C++ `DeviceBackend 1.0` (backend/)
Type QML `Backend` : `batteryInfo()` (sysfs /sys/class/power_supply), `startMicTest(ms)` -> `micFinished(ok,rmsDb,peakDb,msg)` (QAudioInput, seuil pic -40 dBFS dans MicTest.qml), `startWifiScan()` -> `wifiFinished(ok,networks,msg)` (NetworkManager D-Bus système : RequestScan + GetAllAccessPoints). Installé dans `qml/DeviceBackend/`, lancé avec `qmlscene -I qml`. Tests : BatteryTest, MicTest (manuel), WifiTest.

## Limites connues / à faire
- Pas de test NFC, modem/SIM, luminosité écran.
- Plugin jamais compilé (pas de toolchain Qt côté Windows) ; vérifier accès D-Bus système/sysfs en confiné si on resserre l'apparmor.
- Le test réseau ne distingue pas Wi-Fi vs données mobiles (couper l'un des deux à la main).
- Les touches volume peuvent être interceptées par Lomiri avant l'app.
- Pas d'export fichier du rapport (copie presse-papiers seulement).
- Noms/enums QML (Lomiri.Connectivity, QtBluetooth, QtFeedback) à vérifier sur l'image réelle.

## i18n (2026-10-24) — code in English, French translation
- All source strings and comments are **English**. QML: `i18n.tr("...")` (needs `import Lomiri.Components 1.3`); C++: `T("...")` (dgettext). Never `qsTr`.
- Catalog: `po/fr.po` (+ `po/devicetester.jimmy.pot`), compiled by CMake (msgfmt) to `share/locale/fr/LC_MESSAGES/devicetester.jimmy.mo`. `po/update-pot.sh` refreshes the template and merges into every .po (needs xgettext/msgmerge).
- The plugin (`DeviceBackend`, imported by Main.qml) calls bindtextdomain/textdomain("devicetester.jimmy") in `registerTypes`: the default gettext domain is then ours. **Do not set `i18n.domain` in QML** (it breaks the lookup). The phone session language is fr_FR, so the app shows French.
- Add a string: write it in English with `i18n.tr`, run `po/update-pot.sh`, fill `msgstr` in `fr.po`.

## Categories / tests added
- Categories `adv` ("Advanced / SIM": Modem, SIM card, Mobile network, Mobile data via oFono) and `other` (Charger and USB, Memory and storage, Headset jack, Wi-Fi speed, Device information) have `guided: false`: **not** part of the guided assistant, only reachable from their category list. Screen rotation test added to the `screen` category (in the guided run).
- OnePlus 3T findings: oFono sees **no modem** (SIM tests fail/skip), headset jack = /sys/class/switch/h2w/state, USB charger = power_supply `usb` online.
