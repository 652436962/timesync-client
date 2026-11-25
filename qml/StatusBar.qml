import QtQuick
import TimeSync

Rectangle {
    id: bar

    color: Theme.card

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.border
    }

    Text {
        x: 240
        anchors.verticalCenter: parent.verticalCenter
        text: "●"
        color: Theme.green
        font.pixelSize: 9
    }

    Text {
        x: 254
        anchors.verticalCenter: parent.verticalCenter
        text: Engine.serviceLine
        color: Theme.muted
        font.pixelSize: 11
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.verticalCenter: parent.verticalCenter
        text: Engine.clockLine
        color: Theme.muted
        font.pixelSize: 11
    }
}
