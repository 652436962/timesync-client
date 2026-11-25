import QtQuick
import TimeSync

Rectangle {
    id: toast

    property string title: ""
    property string text: ""
    property string tone: "green"

    width: 340
    height: 72
    radius: 10
    color: Theme.darkCard
    border.width: 1
    border.color: Theme.darkCardSoft
    opacity: 0
    visible: opacity > 0
    z: 100

    Behavior on opacity { NumberAnimation { duration: 150 } }

    function show(t, s, tn) {
        title = t
        text = s
        tone = tn || "green"
        opacity = 1
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 4200
        onTriggered: toast.opacity = 0
    }

    Rectangle {
        x: 20
        y: 24
        width: 8
        height: 8
        radius: 4
        color: toast.tone === "red" ? "#E08A7E"
             : toast.tone === "amber" ? "#E7B45C"
             : toast.tone === "blue" ? "#7FA6E0"
             : Theme.accentMint
    }

    Text {
        x: 38
        y: 16
        width: parent.width - 56
        text: toast.title
        color: "#FFFFFF"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        x: 38
        y: 37
        width: parent.width - 56
        text: toast.text
        color: Theme.heroMuted
        font.pixelSize: 11
        elide: Text.ElideRight
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toast.opacity = 0
    }
}
