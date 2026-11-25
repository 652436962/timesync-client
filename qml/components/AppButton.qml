import QtQuick
import TimeSync

Rectangle {
    id: btn

    property string text: ""
    property bool primary: false
    signal clicked()

    width: 96
    height: 36
    radius: 9
    color: primary
           ? (hover.hovered ? Qt.darker(Theme.green, 1.08) : Theme.green)
           : (hover.hovered ? Theme.hover : Theme.card)
    border.width: primary ? 0 : 1
    border.color: Theme.border

    Text {
        anchors.centerIn: parent
        text: btn.text
        color: btn.primary ? "#FFFFFF" : Theme.ink
        font.pixelSize: 13
        font.weight: btn.primary ? Font.DemiBold : Font.Medium
        font.family: Theme.fontFamily
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
