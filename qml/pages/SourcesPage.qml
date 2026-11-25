import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    PageHeader {
        width: parent.width
        title: "时钟源"
        subtitle: "配置本机可用时钟源，按优先级自动择优"
        actions: [
            { label: "添加时钟源", primary: true, key: "add" }
        ]
        onAction: (key) => {
            if (key === "add")
                addDialog.open()
        }
    }

    AppCard {
        y: 108
        width: parent.width
        height: 420

        Text {
            x: 20
            y: 18
            text: "时钟源列表"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 118
            y: 22
            text: "拖动调整优先级"
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
                { text: "优先级", x: 20 },
                { text: "时钟源", x: 90 },
                { text: "地址", x: 320 },
                { text: "协议", x: 470 },
                { text: "层级", x: 560 },
                { text: "偏差", x: 630 },
                { text: "状态", x: 730 }
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

        ListView {
            id: srcList
            y: 84
            width: parent.width
            height: 336
            clip: true
            model: Engine.sources
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: srcList.contentHeight > srcList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                width: 6
                anchors.right: parent.right
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.track
                }
            }

            delegate: Item {
                id: rowItem
                width: srcList.width
                height: 68

                Rectangle {
                    x: 20
                    y: 67
                    width: parent.width - 40
                    height: 1
                    color: Theme.rowLine
                    visible: index < Engine.sources.length - 1
                }

                Rectangle {
                    x: 20
                    y: 20
                    width: 30
                    height: 24
                    radius: 6
                    color: modelData.primary ? Theme.greenSoft
                         : modelData.system ? Theme.toneSoft("muted") : Theme.blueSoft

                    Text {
                        anchors.centerIn: parent
                        text: modelData.primary ? "主" : (modelData.system ? "-" : "备")
                        color: modelData.primary ? Theme.green
                             : modelData.system ? Theme.muted : Theme.blue
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    x: 60
                    y: 20
                    spacing: 3

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            width: 8
                            height: 2
                            radius: 1
                            color: Theme.navIcon
                        }
                    }
                }

                Text {
                    x: 90
                    y: 12
                    width: 220
                    text: modelData.name
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    x: 90
                    y: 34
                    width: 220
                    text: modelData.desc
                    color: Theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    x: 320
                    y: 22
                    width: 150
                    text: modelData.host
                    color: Theme.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    x: 470
                    y: 22
                    text: modelData.proto
                    color: Theme.ink
                    font.pixelSize: 12
                }

                Text {
                    x: 560
                    y: 22
                    text: modelData.stratum
                    color: Theme.ink
                    font.pixelSize: 12
                }

                Text {
                    x: 630
                    y: 22
                    width: 90
                    text: modelData.offset
                    color: modelData.system ? Theme.muted : Theme.tone(modelData.tone)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Pill {
                    x: 730
                    y: 20
                    text: modelData.status
                    tone: modelData.tone
                }

                Toggle {
                    x: parent.width - 58
                    y: 20
                    checked: modelData.enabled
                    interactive: !modelData.system
                    onToggled: (value) => Engine.setSourceEnabled(index, value)
                }

                Rectangle {
                    x: parent.width - 128
                    y: 16
                    width: 48
                    height: 26
                    radius: 6
                    color: removeMouse.containsMouse ? Theme.redSoft : "transparent"
                    visible: rowMouse.hovered && !modelData.system

                    Text {
                        anchors.centerIn: parent
                        text: "移除"
                        color: Theme.red
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Engine.removeSource(index)
                    }
                }

                HoverHandler {
                    id: rowMouse
                }
            }
        }
    }

    // -------- strategy
    AppCard {
        y: 548
        width: (parent.width - 16) / 2
        height: 130

        Text {
            x: 20
            y: 18
            text: "择优策略"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Repeater {
            model: [
                { name: "层级优先", note: "选择最小 stratum" },
                { name: "延迟优先", note: "选择最小 RTT" },
                { name: "稳定优先", note: "历史抖动最小" }
            ]

            delegate: RadioDot {
                x: 20
                y: 38 + index * 30
                width: parent.width - 40
                checked: Engine.strategy === modelData.name
                label: modelData.name
                note: modelData.note
                onClicked: Engine.strategy = modelData.name
            }
        }
    }

    // -------- connection test
    AppCard {
        x: (parent.width + 16) / 2
        y: 548
        width: (parent.width - 16) / 2
        height: 130

        Text {
            x: 20
            y: 18
            text: "连接测试"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 20
            y: 44
            width: parent.width - 40
            text: "目标：" + Engine.serverHost + ":" + Engine.serverPort
            color: Theme.ink
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Text {
            x: 20
            y: 64
            width: parent.width - 40
            text: Engine.lastTestText
            color: Theme.muted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Rectangle {
            x: 20
            y: 90
            width: 300
            height: 4
            radius: 2
            color: Theme.greenSoft

            Rectangle {
                width: Engine.testing ? parent.width * 0.55 : parent.width
                height: 4
                radius: 2
                color: Theme.green
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        Text {
            x: 20
            y: 102
            text: Engine.testing ? "正在测试…" : "重新测试"
            color: Theme.green
            font.pixelSize: 11
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Engine.testPrimary()
            }
        }
    }

    // -------- add source dialog
    Popup {
        id: addDialog
        focus: true
        width: 400
        height: 244
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
            implicitWidth: 400
            implicitHeight: 244

            Text {
                x: 24
                y: 18
                text: "添加时钟源"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                x: 24
                y: 54
                text: "服务器地址"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Rectangle {
                x: 24
                y: 72
                width: 352
                height: 38
                radius: 8
                color: Theme.fieldBg
                border.width: 1
                border.color: hostInput.activeFocus ? Theme.green : Theme.border

                TextInput {
                    id: hostInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.ink
                    font.pixelSize: 13
                    selectionColor: Theme.green
                    selectedTextColor: "#FFFFFF"
                    clip: true
                    Text {
                        text: "ntp.example.com"
                        color: Theme.faint
                        font.pixelSize: 13
                        visible: !hostInput.text && !hostInput.activeFocus
                    }
                }
            }

            Text {
                x: 24
                y: 120
                text: "显示名称（可选）"
                color: Theme.muted
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Rectangle {
                x: 24
                y: 138
                width: 352
                height: 38
                radius: 8
                color: Theme.fieldBg
                border.width: 1
                border.color: nameInput.activeFocus ? Theme.green : Theme.border

                TextInput {
                    id: nameInput
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

            Row {
                x: 24
                y: 192
                spacing: 12

                AppButton {
                    text: "添加"
                    primary: true
                    width: 96
                    onClicked: {
                        Engine.addSource(hostInput.text, nameInput.text)
                        hostInput.text = ""
                        nameInput.text = ""
                        addDialog.close()
                    }
                }

                AppButton {
                    text: "取消"
                    onClicked: addDialog.close()
                }
            }
        }
    }
}
