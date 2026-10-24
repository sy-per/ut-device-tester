import QtQuick 2.12
import Lomiri.Components 1.3

// Filled button with icon + text in controlled colors (the toolkit Button cannot tint its icon).
Rectangle {
    id: root
    property string text: ""
    property string iconName: ""
    property color fill: theme.palette.normal.positive
    property color fg: "white"
    signal clicked()

    implicitHeight: units.gu(6)
    radius: units.gu(1)
    color: press.pressed ? Qt.darker(fill, 1.15) : fill

    Row {
        anchors.centerIn: parent
        spacing: units.gu(1)
        Icon {
            visible: root.iconName !== ""
            width: units.gu(2.6); height: width
            name: root.iconName
            color: root.fg
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            text: root.text
            color: root.fg
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea { id: press; anchors.fill: parent; onClicked: root.clicked() }
}
