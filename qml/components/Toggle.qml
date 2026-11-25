import QtQuick
import TimeSync

Item {
    id: toggle

    property bool checked: false
    property bool interactive: true
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 22
    opacity: interactive ? 1.0 : 0.5

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? Theme.green : Theme.track
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        id: knob
        width: 16
        height: 16
        radius: 8
        y: 3
        x: toggle.checked ? parent.width - width - 3 : 3
        color: "#FFFFFF"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: toggle.interactive
        cursorShape: toggle.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
