import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    property string newLevel: "提示"

    PageHeader {
        width: parent.width
        title: "告警规则"
        subtitle: "定义何时记录事件、何时弹窗提醒"
        actions: [
            { label: "新建规则", primary: true, key: "new" }
        ]
        onAction: (key) => {
            if (key === "new")
                newRule.open()
        }
    }

    AppCard {
        y: 108
        width: parent.width
        height: 392

        Text {
            x: 20
            y: 18
            text: "告警规则"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 98
            y: 22
            text: "共 " + Engine.rules.length + " 条"
            color: Theme.muted
            font.pixelSize: 11
        }

        Rectangle {
            x: 1
            y: 52
            width: parent.width - 2
            height: 32
            color: Theme.tableHead
        }

        Repeater {
            model: [
                { text: "规则名称", x: 20 },
                { text: "触发条件", x: 210 },
                { text: "动作", x: 560 },
                { text: "级别", x: 700 }
            ]

            delegate: Text {
                x: modelData.x
                y: 61
                text: modelData.text
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        Repeater {
            model: Engine.rules

            delegate: Item {
                y: 84 + index * 72
                width: parent.width
                height: 72

                Rectangle {
                    x: 20
                    y: 71
                    width: parent.width - 40
                    height: 1
                    color: Theme.rowLine
                    visible: index < Engine.rules.length - 1
                }

                Text {
                    x: 20
                    y: 18
                    width: 180
                    text: modelData.name
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    opacity: modelData.enabled ? 1.0 : 0.6
                }

                Text {
                    x: 210
                    y: 18
                    width: 330
                    text: modelData.condition
                    color: Theme.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    opacity: modelData.enabled ? 1.0 : 0.6
                }

                Text {
                    x: 560
                    y: 18
                    text: modelData.action
                    color: Theme.ink
                    font.pixelSize: 12
                    opacity: modelData.enabled ? 1.0 : 0.6
                }

                Pill {
                    x: 700
                    y: 16
                    text: modelData.level
                    tone: modelData.tone
                }

                Toggle {
                    x: parent.width - 58
                    y: 16
                    checked: modelData.enabled
                    onToggled: (value) => Engine.setRuleEnabled(modelData.index, value)
                }
            }
        }
    }

    AppCard {
        y: 516
        width: parent.width
        height: 162

        Text {
            x: 20
            y: 16
            text: "通知方式"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 96
            y: 20
            text: "告警触发后如何提醒"
            color: Theme.muted
            font.pixelSize: 11
        }

        Repeater {
            model: [
                { name: "系统通知", desc: "在桌面右下角弹出气泡", icon: "◉", key: "system",
                  on: Engine.notifySystem, tone: "green" },
                { name: "邮件通知", desc: "发送至 chenzhiyuan@corp.lan", icon: "✉", key: "mail",
                  on: Engine.notifyMail, tone: "green" },
                { name: "Webhook", desc: "推送到运维平台 https://ops.corp.lan/hook", icon: "↗", key: "webhook",
                  on: Engine.notifyWebhook, tone: "muted" }
            ]

            delegate: Item {
                y: 46 + index * 40
                width: parent.width
                height: 40

                Rectangle {
                    x: 20
                    y: 4
                    width: 32
                    height: 32
                    radius: 8
                    color: Theme.toneSoft(modelData.tone)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: Theme.tone(modelData.tone)
                        font.pixelSize: 15
                    }
                }

                Text {
                    x: 64
                    y: 2
                    text: modelData.name
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    x: 64
                    y: 21
                    width: 620
                    text: modelData.desc
                    color: Theme.muted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Toggle {
                    x: parent.width - 58
                    y: 6
                    checked: modelData.on
                    onToggled: (value) => Engine.setNotify(modelData.key, value)
                }
            }
        }
    }

    Popup {
        id: newRule
        focus: true
        width: 440
        height: 328
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: Theme.card
            radius: 12
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 440
            implicitHeight: 328

            Text {
                x: 24
                y: 18
                text: "新建告警规则"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                x: 24
                y: 52
                text: "规则名称"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Rectangle {
                x: 24
                y: 70
                width: 392
                height: 38
                radius: 8
                color: Theme.fieldBg
                border.width: 1
                border.color: ruleName.activeFocus ? Theme.green : Theme.border

                TextInput {
                    id: ruleName
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.ink
                    font.pixelSize: 13
                    selectionColor: Theme.green
                    selectedTextColor: "#FFFFFF"
                    clip: true
                }
            }

            Text {
                x: 24
                y: 118
                text: "触发条件"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Rectangle {
                x: 24
                y: 136
                width: 392
                height: 38
                radius: 8
                color: Theme.fieldBg
                border.width: 1
                border.color: ruleCondition.activeFocus ? Theme.green : Theme.border

                TextInput {
                    id: ruleCondition
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.ink
                    font.pixelSize: 13
                    selectionColor: Theme.green
                    selectedTextColor: "#FFFFFF"
                    clip: true
                }
            }

            Text {
                x: 24
                y: 184
                text: "级别"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Row {
                x: 24
                y: 202
                spacing: 8

                Repeater {
                    model: [
                        { label: "警告", tone: "amber" },
                        { label: "严重", tone: "red" },
                        { label: "提示", tone: "blue" }
                    ]

                    delegate: Rectangle {
                        width: 64
                        height: 26
                        radius: 13
                        color: page.newLevel === modelData.label ? Theme.toneSoft(modelData.tone)
                             : hover.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: page.newLevel === modelData.label ? Theme.tone(modelData.tone)
                                                                       : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: page.newLevel === modelData.label ? Theme.tone(modelData.tone)
                                                                    : Theme.muted
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        HoverHandler { id: hover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.newLevel = modelData.label
                        }
                    }
                }
            }

            Text {
                x: 24
                y: 240
                text: "动作：仅记录（弹窗提醒可在阈值页配置）"
                color: Theme.faint
                font.pixelSize: 11
            }

            Row {
                x: 24
                y: 276
                spacing: 12

                AppButton {
                    text: "创建"
                    primary: true
                    width: 96
                    onClicked: {
                        Engine.addRule(ruleName.text, ruleCondition.text, "仅记录", page.newLevel)
                        ruleName.text = ""
                        ruleCondition.text = ""
                        newRule.close()
                    }
                }

                AppButton {
                    text: "取消"
                    onClicked: newRule.close()
                }
            }
        }
    }
}
