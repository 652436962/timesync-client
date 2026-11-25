import QtQuick
import QtQuick.Controls
import TimeSync

Rectangle {
    id: side

    property int current: 0
    signal navigate(int index)

    color: Theme.card

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.border
    }

    Text {
        x: 20
        y: 24
        text: "本机"
        color: Theme.muted
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Repeater {
        model: [
            { label: "连接状态", badge: Engine.paused ? "暂停" : (Engine.stateTone === "red" ? "未同步" : "已同步"),
              badgeTone: Engine.paused ? "muted" : (Engine.stateTone === "red" ? "red" : "green") },
            { label: "时钟源", badge: String(Engine.sourceCount), badgeTone: "muted" },
            { label: "同步历史", badge: "", badgeTone: "muted" },
            { label: "偏差监控", badge: "", badgeTone: "muted" },
            { label: "事件日志", badge: Engine.unreadCount > 0 ? String(Engine.unreadCount) : "", badgeTone: "red" }
        ]

        delegate: Rectangle {
            x: 12
            y: 48 + index * 40
            width: side.width - 24
            height: 36
            radius: 8
            color: side.current === index ? Theme.greenSoft
                 : hover.containsMouse ? Theme.hover : "transparent"

            Rectangle {
                x: 12
                y: 9
                width: 14
                height: 14
                radius: 4
                color: side.current === index ? Theme.green : Theme.navIcon
            }

            Text {
                x: 36
                y: 6
                text: modelData.label
                color: side.current === index ? Theme.green : Theme.ink
                font.pixelSize: 13
                font.weight: side.current === index ? Font.Medium : Font.Normal
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.badge
                color: modelData.badgeTone === "red" ? Theme.red
                     : modelData.badgeTone === "green" ? Theme.green : Theme.muted
                font.pixelSize: 12
                font.weight: modelData.badgeTone === "red" ? Font.Medium : Font.Normal
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: side.navigate(index)
            }
        }
    }

    Text {
        x: 20
        y: 284
        text: "系统"
        color: Theme.muted
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Repeater {
        model: ["服务器配置", "告警规则", "偏好设置"]

        delegate: Rectangle {
            x: 12
            y: 308 + index * 40
            width: side.width - 24
            height: 36
            radius: 8
            color: side.current === index + 5 ? Theme.greenSoft
                 : hover2.containsMouse ? Theme.hover : "transparent"

            Rectangle {
                x: 12
                y: 9
                width: 14
                height: 14
                radius: 4
                color: side.current === index + 5 ? Theme.green : Theme.navIcon
            }

            Text {
                x: 36
                y: 6
                text: modelData
                color: side.current === index + 5 ? Theme.green : Theme.ink
                font.pixelSize: 13
                font.weight: side.current === index + 5 ? Font.Medium : Font.Normal
            }

            HoverHandler { id: hover2 }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: side.navigate(index + 5)
            }
        }
    }

    Rectangle {
        id: helpCard
        x: 12
        y: side.height - 78
        width: side.width - 24
        height: 60
        radius: 10
        color: helpHover.containsMouse ? Theme.hover : Theme.bg

        Rectangle {
            x: 10
            y: 16
            width: 28
            height: 28
            radius: 8
            color: Theme.green

            Text {
                anchors.centerIn: parent
                text: "?"
                color: "#FFFFFF"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        Text {
            x: 48
            y: 13
            text: "帮助"
            color: Theme.ink
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Text {
            x: 48
            y: 31
            text: "使用说明与常见问题"
            color: Theme.muted
            font.pixelSize: 11
        }

        HoverHandler { id: helpHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: helpPopup.open()
        }
    }

    Popup {
        id: helpPopup
        focus: true
        width: 480
        modal: true
        padding: 0
        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.card
            radius: 12
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 480
            implicitHeight: 372

            Text {
                x: 24
                y: 20
                text: "帮助"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                x: 24
                y: 47
                text: Engine.versionLine
                color: Theme.muted
                font.pixelSize: 11
            }

            Rectangle {
                x: 24
                y: 72
                width: 432
                height: 1
                color: Theme.rowLine
            }

            Column {
                x: 24
                y: 88
                width: 432
                spacing: 12

                Repeater {
                    model: [
                        { title: "同步方式",
                          desc: "每 4 秒轮询已启用的时钟源，按层级 / 延迟 / 稳定策略择优选定主时钟，探测走 SNTP v4（UDP 123）。" },
                        { title: "告警触发",
                          desc: "偏差需连续 3 次采样超过阈值才会记录并提醒，回落到阈值的 80% 以下后自动复位。" },
                        { title: "主时钟切换",
                          desc: "切换后 2 分钟内不重复记录切换事件；当前主时钟始终显示在标题栏与状态栏。" },
                        { title: "托盘与关闭",
                          desc: "双击托盘图标显示或隐藏窗口；关闭窗口的行为可在「偏好设置」中调整。" }
                    ]

                    delegate: Item {
                        width: 432
                        height: 44

                        Text {
                            x: 0
                            y: 0
                            text: modelData.title
                            color: Theme.ink
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Text {
                            x: 0
                            y: 18
                            width: 432
                            text: modelData.desc
                            color: Theme.muted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }
                }
            }

            AppButton {
                x: 24
                y: 316
                text: "关闭"
                primary: true
                width: 96
                onClicked: helpPopup.close()
            }
        }
    }
}
