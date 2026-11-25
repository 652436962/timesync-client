import QtQuick
import TimeSync

Item {
    id: radio

    property bool checked: false
    property string label: ""
    property string note: ""
    signal clicked()

    implicitWidth: labelText.implicitWidth + 28
    implicitHeight: 20

    Rectangle {
        id: circle
        width: 16
        height: 16
        radius: 8
        y: 2
        color: radio.checked ? Theme.green : "transparent"
        border.width: 1
        border.color: radio.checked ? Theme.green : "#C4CFCB"

        Rectangle {
            width: 6
            height: 6
            radius: 3
            anchors.centerIn: parent
            color: "#FFFFFF"
            visible: radio.checked
        }
    }

    Text {
        id: labelText
        x: 26
        text: radio.label
        color: Theme.ink
        font.pixelSize: 12
        font.weight: radio.checked ? Font.Medium : Font.Normal
    }

    Text {
        x: 108
        text: radio.note
        color: Theme.muted
        font.pixelSize: 11
        visible: radio.note.length > 0
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: radio.clicked()
    }
}
