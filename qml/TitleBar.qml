import QtQuick
import TimeSync

Rectangle {
    id: bar

    signal minimizeRequested()
    signal maximizeRequested()
    signal closeRequested()

    color: Theme.card

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.border
    }

    Rectangle {
        x: 20
        y: 14
        width: 24
        height: 24
        radius: 7
        color: Theme.green

        Text {
            anchors.centerIn: parent
            text: "◷"
            color: "#FFFFFF"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }

    Text {
        x: 52
        y: 17
        text: "TimeSync"
        color: Theme.ink
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    Text {
        x: 130
        y: 20
        width: parent.width - 130 - 160
        text: Engine.headerStatus
        color: Theme.muted
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Repeater {
            model: [
                { key: "min", color: "#E0B84C" },
                { key: "max", color: "#5AAE8D" },
                { key: "close", color: "#D06A5E" }
            ]

            delegate: Rectangle {
                width: 12
                height: 12
                radius: 6
                color: mouse.containsMouse ? modelData.color : "#C9D1CE"

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.key === "min")
                            bar.minimizeRequested()
                        else if (modelData.key === "max")
                            bar.maximizeRequested()
                        else
                            bar.closeRequested()
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onPressed: {
            const win = bar.Window.window
            if (win)
                win.startSystemMove()
        }
        onDoubleClicked: bar.maximizeRequested()
        z: -1
    }
}
