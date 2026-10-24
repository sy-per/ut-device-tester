import QtQuick 2.12
import Lomiri.Components 1.3
import QtMultimedia 5.12
import ".."

// Opens camera #cameraIndex, waits for the active state, takes a photo.
TestBase {
    id: root
    timeoutMs: 20000
    property int cameraIndex: 0
    property bool captured: false
    readonly property var info: QtMultimedia.availableCameras[cameraIndex]

    Camera {
        id: cam
        deviceId: root.info ? root.info.deviceId : ""
        captureMode: Camera.CaptureStillImage
        cameraState: Camera.UnloadedState
        onCameraStatusChanged: {
            if (cameraStatus === Camera.ActiveStatus && !root.captured) {
                root.captured = true
                root.note(i18n.tr("Camera active, capturing…"))
                shot.start()
            }
        }
        onError: root.fail(i18n.tr("Camera error: ") + errorString)
        imageCapture {
            onImageSaved: root.pass(i18n.tr("Capture OK: ") + path)
            onCaptureFailed: root.fail(i18n.tr("Capture failed: ") + message)
        }
    }

    VideoOutput {
        anchors.fill: parent
        source: cam
        fillMode: VideoOutput.PreserveAspectCrop
        autoOrientation: true
    }

    Timer { id: shot; interval: 1500; onTriggered: cam.imageCapture.capture() }

    function run() {
        if (!info) { fail(i18n.tr("No camera detected")); return }
        note(i18n.tr("Opening ") + info.displayName)
        cam.cameraState = Camera.ActiveState
    }
    function cleanup() { shot.stop(); cam.cameraState = Camera.UnloadedState }
}
