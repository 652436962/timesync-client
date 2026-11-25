import QtQuick
import QtQuick.Controls
import TimeSync

Rectangle {
    id: bar

    signal minimizeRequested()
    signal maximizeRequested()
    signal closeRequested()

    property int eggClicks: 0

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
            id: logoGlyph
            anchors.centerIn: parent
            text: "◷"
            color: "#FFFFFF"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                bar.eggClicks++
                eggReset.restart()
                if (bar.eggClicks >= 5) {
                    bar.eggClicks = 0
                    eggReset.stop()
                    easterEgg.open()
                }
            }
        }
    }

    Timer {
        id: eggReset
        interval: 2000
        onTriggered: bar.eggClicks = 0
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

    Popup {
        id: easterEgg
        width: 420
        modal: true
        focus: true
        padding: 0
        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.card
            radius: 14
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 420
            implicitHeight: 294

            Rectangle {
                x: 24
                y: 24
                width: 48
                height: 48
                radius: 12
                color: Theme.green

                Text {
                    anchors.centerIn: parent
                    text: "◷"
                    color: "#FFFFFF"
                    font.pixelSize: 26
                    font.weight: Font.DemiBold

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 1200
                        running: easterEgg.opened
                    }
                }
            }

            Text {
                x: 88
                y: 29
                text: "彩蛋 · 时差 0.000 s"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                x: 88
                y: 53
                text: "关于时钟的两条冷知识"
                color: Theme.muted
                font.pixelSize: 11
            }

            Rectangle {
                x: 24
                y: 84
                width: 372
                height: 1
                color: Theme.rowLine
            }

            Text {
                x: 24
                y: 100
                width: 372
                text: "北京时间并不在北京产生 —— 国家授时中心在陕西临潼。\n\nNTP 的 32 位秒计数会在 2036 年 2 月 7 日回绕，和千年虫是同款问题。"
                color: Theme.ink
                font.pixelSize: 12
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            Text {
                x: 24
                y: 198
                text: "— freeor · 嵌入式 / Qt / 无人机地面站"
                color: Theme.green
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Text {
                x: 24
                y: 215
                text: "业余爱好：在 Deepin 上把时间对到 1 ms 以内"
                color: Theme.muted
                font.pixelSize: 11
            }

            AppButton {
                x: 24
                y: 244
                width: 116
                text: "收下彩蛋"
                primary: true
                onClicked: easterEgg.close()
            }
        }
    }
}
