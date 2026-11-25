import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    property int pollChoice: Engine.pollSec

    function pollLabel() {
        if (Engine.pollSec <= 4)
            return "自适应（4 秒轮询 / 128 秒步进）"
        if (Engine.pollSec <= 16)
            return "均衡（16 秒轮询 / 128 秒步进）"
        return "省电（64 秒轮询 / 128 秒步进）"
    }

    function poolSources() {
        const out = []
        const src = Engine.sources
        for (let i = 0; i < src.length; ++i) {
            if (!src[i].system && !src[i].primary)
                out.push(src[i])
        }
        return out.slice(0, 3)
    }

    Component.onCompleted: {
        hostInput.text = Engine.serverHost
        portInput.text = String(Engine.serverPort)
    }

    Connections {
        target: Engine
        function onConfigChanged() {
            if (!hostInput.activeFocus)
                hostInput.text = Engine.serverHost
            if (!portInput.activeFocus)
                portInput.text = String(Engine.serverPort)
        }
    }

    PageHeader {
        width: parent.width
        title: "服务器配置"
        subtitle: "设置要同步的上游授时服务器"
        actions: [
            { label: "测试全部", key: "test" },
            { label: "保存更改", primary: true, key: "save" }
        ]
        onAction: (key) => {
            if (key === "save")
                Engine.saveServerConfig(hostInput.text, portInput.text)
            else
                Engine.testAll()
        }
    }

    AppCard {
        y: 108
        width: parent.width
        height: 292

        Text {
            x: 20
            y: 18
            text: "连接参数"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        // row 1
        Text {
            x: 20
            y: 44
            text: "服务器地址"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            x: 20
            y: 64
            width: 430
            height: 40
            radius: 8
            color: Theme.fieldBg
            border.width: 1
            border.color: hostInput.activeFocus ? Theme.green : Theme.border

            TextInput {
                id: hostInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.ink
                font.pixelSize: 13
                selectionColor: Theme.green
                selectedTextColor: "#FFFFFF"
                clip: true

                Component.onCompleted: text = Engine.serverHost
            }
        }

        Text {
            x: 478
            y: 44
            text: "端口"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            x: 478
            y: 64
            width: 430
            height: 40
            radius: 8
            color: Theme.fieldBg
            border.width: 1
            border.color: portInput.activeFocus ? Theme.green : Theme.border

            TextInput {
                id: portInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.ink
                font.pixelSize: 13
                selectionColor: Theme.green
                selectedTextColor: "#FFFFFF"
                clip: true
                inputMethodHints: Qt.ImhDigitsOnly
                Component.onCompleted: text = String(Engine.serverPort)
            }
        }

        // row 2
        Text {
            x: 20
            y: 132
            text: "协议"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            x: 20
            y: 152
            width: 430
            height: 40
            radius: 8
            color: Theme.fieldBg
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "NTPv4（UDP / SNTP）"
                color: Theme.ink
                font.pixelSize: 13
            }
        }

        Text {
            x: 478
            y: 132
            text: "认证方式"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            x: 478
            y: 152
            width: 430
            height: 40
            radius: 8
            color: Theme.fieldBg
            border.width: 1
            border.color: Theme.border

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "无认证 · 明文 SNTP"
                color: Theme.ink
                font.pixelSize: 13
            }
        }

        // row 3
        Text {
            x: 20
            y: 226
            text: "轮询策略"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            id: pollBox
            x: 20
            y: 246
            width: 500
            height: 40
            radius: 8
            color: Theme.fieldBg
            border.width: 1
            border.color: pollHover.containsMouse ? Theme.green : Theme.border

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: page.pollLabel()
                color: Theme.ink
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "⌄"
                color: Theme.faint
                font.pixelSize: 14
            }

            HoverHandler { id: pollHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pollMenu.open()
            }
        }

        Text {
            x: 700
            y: 250
            text: "启用 NTS 加密"
            color: Theme.ink
            font.pixelSize: 12
        }

        Text {
            x: 700
            y: 268
            text: "当前为 SNTP 明文，暂不支持"
            color: Theme.faint
            font.pixelSize: 10
        }

        Toggle {
            x: 856
            y: 254
            checked: Engine.ntsEnabled
            onToggled: (value) => Engine.setNtsEnabled(value)
        }
    }

    AppCard {
        y: 416
        width: parent.width
        height: 178

        Text {
            x: 20
            y: 18
            text: "备用服务器池"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 130
            y: 22
            text: "自动故障切换"
            color: Theme.muted
            font.pixelSize: 11
        }

        Repeater {
            model: page.poolSources()

            delegate: Item {
                y: 52 + index * 44
                width: parent.width
                height: 44

                Text {
                    x: 20
                    y: 4
                    text: "◷"
                    color: Theme.tone(modelData.tone)
                    font.pixelSize: 15
                }

                Text {
                    x: 46
                    y: 1
                    width: 240
                    text: modelData.host
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    x: 46
                    y: 21
                    text: "stratum " + modelData.stratum
                    color: Theme.muted
                    font.pixelSize: 10
                }

                Text {
                    x: 420
                    y: 8
                    width: 90
                    text: modelData.delay
                    color: Theme.muted
                    font.pixelSize: 12
                }

                Pill {
                    x: 520
                    y: 6
                    text: modelData.status
                    tone: modelData.tone
                }

                Toggle {
                    x: parent.width - 58
                    y: 6
                    checked: modelData.enabled
                    onToggled: (value) => Engine.setSourceEnabled(modelData.index, value)
                }
            }
        }
    }

    AppCard {
        y: 610
        width: parent.width
        height: 68

        Text {
            x: 20
            y: 12
            text: "高级选项"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        CheckBoxItem {
            x: 20
            y: 40
            label: "开机自动校时"
            checked: Engine.autostart
            onToggled: (v) => Engine.autostart = v
        }

        CheckBoxItem {
            x: 220
            y: 40
            label: "断网后保持本地时钟"
            checked: Engine.keepLocalTime
            onToggled: (v) => Engine.keepLocalTime = v
        }

        CheckBoxItem {
            x: 460
            y: 40
            label: "允许向上游回写时间"
            checked: Engine.allowWriteBack
            labelColor: Theme.muted
            onToggled: (v) => Engine.allowWriteBack = v
        }

        CheckBoxItem {
            x: 700
            y: 40
            label: "校时前记录系统时间快照"
            checked: Engine.snapshotBefore
            onToggled: (v) => Engine.snapshotBefore = v
        }
    }

    Popup {
        id: pollMenu
        focus: true
        width: 260
        padding: 6
        x: 20
        y: 388
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            color: Theme.card
            radius: 10
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Column {
            spacing: 2

            Repeater {
                model: [
                    { sec: 4, label: "自适应（4 秒轮询 / 128 秒步进）" },
                    { sec: 16, label: "均衡（16 秒轮询 / 128 秒步进）" },
                    { sec: 64, label: "省电（64 秒轮询 / 128 秒步进）" }
                ]

                delegate: Rectangle {
                    width: 248
                    height: 34
                    radius: 7
                    color: hover.containsMouse ? Theme.hover : "transparent"

                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Engine.pollSec === modelData.sec ? Theme.green : Theme.ink
                        font.pixelSize: 12
                    }

                    HoverHandler { id: hover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Engine.pollSec = modelData.sec
                            pollMenu.close()
                        }
                    }
                }
            }
        }
    }
}
