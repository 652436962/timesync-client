import QtQuick
import TimeSync

Rectangle {
    id: pill

    property string text: ""
    property string tone: "green"
    property int fontSize: 10

    implicitWidth: label.implicitWidth + 18
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight
    radius: 11
    color: Theme.toneSoft(tone)

    Text {
        id: label
        anchors.centerIn: parent
        text: pill.text
        color: Theme.tone(pill.tone)
        font.pixelSize: pill.fontSize
        font.weight: Font.Medium
        font.family: Theme.fontFamily
    }
}
