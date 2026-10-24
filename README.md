# Device Tester

Hardware self-test app for [Ubuntu Touch](https://ubports.com): a guided assistant (plus single tests grouped by
category) that checks a phone's hardware and produces a report.

- **Screen and touch**: colors, multi-touch, volume buttons, rotation
- **Audio and vibration**: vibration motor, speaker, microphone
- **Cameras and flashlight**
- **Network and location**: internet, Wi-Fi scan, Bluetooth, GPS
- **Sensors**: accelerometer, gyroscope, magnetometer, compass, orientation, proximity, light, barometer
- **Battery and storage**
- **Advanced / SIM** (not part of the guided run): modem, SIM card, mobile network, mobile data (oFono)
- **Other** (not part of the guided run): charger and USB, memory and storage, headset jack, Wi-Fi speed, device information

The report can be copied or saved to `~/Documents`.

## Build

The app uses a small C++ QML plugin (`DeviceBackend`) for what QML cannot reach: sysfs (battery, flashlight, headset),
the microphone, NetworkManager and oFono over D-Bus.

```bash
clickable build --arch arm64        # or: clickable desktop
```

`build.sh` builds from WSL and copies the package to `dist/` (Clickable refuses paths containing spaces).

> The app uses the `unconfined` AppArmor template because it reads sysfs and talks to the system D-Bus.

## Translations

Source strings are English (`i18n.tr("...")` in QML, `T("...")` in C++). French lives in `po/fr.po`;
run `po/update-pot.sh` after adding strings, then fill in the `msgstr` entries.

## License

GNU GPL v3 or later, see [LICENSE](LICENSE).

Copyright (C) 2026 Jimmy Lejeune <jimmy@makeinweb.fr>
