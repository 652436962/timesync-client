import QtQuick
import TimeSync

Item {
    id: header

    property string title: ""
    property string subtitle: ""
    property var actions: []
    signal action(string key)

    height: 108

    Text {
        x: 0
        y: 34
        text: header.title
        color: Theme.ink
        font.pixelSize: 24
        font.weight: Font.Bold
        font.family: Theme.fontFamily
    }

    Text {
        x: 0
        y: 70
        width: Math.max(300, parent.width - 360)
        text: header.subtitle
        color: Theme.muted
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Row {
        anchors.right: parent.right
        y: 38
        spacing: 12

        Repeater {
            model: header.actions

            delegate: AppButton {
                text: modelData.label
                primary: modelData.primary === true
                width: text.length <= 4 ? 96 : 108
                onClicked: header.action(modelData.key)
            }
        }
    }
}
