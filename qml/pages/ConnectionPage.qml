import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    signal requestPage(int index)

    PageHeader {
        width: parent.width
        title: "连接状态"
        subtitle: Engine.deviceLine
        actions: [
            { label: "高级…", key: "advanced" },
            { label: "立即同步", primary: true, key: "sync" }
        ]
        onAction: (key) => {
            if (key === "sync")
                Engine.syncNow()
            else
                advanced.open()
        }
    }

    // -------- hero status card
    Rectangle {
        id: hero
        y: 108
        width: parent.width
        height: 168
        radius: 14
        color: Theme.darkCard

        Text {
            x: 28
            y: 24
            text: "本机时钟状态"
            color: Theme.heroLabel
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Rectangle {
            x: 28
            y: 52
            width: 52
            height: 52
            radius: 26
            color: Theme.darkCardSoft

            Text {
                anchors.centerIn: parent
                text: Engine.paused ? "Ⅱ" : (Engine.syncing ? "⋯" : (Engine.stateTone === "green" ? "✓" : "!"))
                color: Theme.accentMint
                font.pixelSize: Engine.paused ? 18 : 24
                font.weight: Font.DemiBold
            }
        }

        Text {
            x: 96
            y: 48
            text: Engine.stateText
            color: "#FFFFFF"
            font.pixelSize: 28
            font.weight: Font.Bold
        }

        Text {
            x: 96
            y: 86
            width: 360
            text: Engine.stateDesc
            color: Theme.heroMuted
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        // metrics
        Repeater {
            model: [
                { label: "当前偏差", value: Engine.offsetText.replace(" ms", ""), unit: "ms", mint: true },
                { label: "往返延迟", value: Engine.delayText.replace(" ms", ""), unit: "ms", mint: false },
                { label: "时钟层级", value: Engine.stratumText, unit: "层", mint: false }
            ]

            delegate: Item {
                x: 460 + index * 128
                y: 38
                width: 120
                height: 80

                Text {
                    x: 0
                    y: 2
                    text: modelData.label
                    color: Theme.heroLabel
                    font.pixelSize: 11
                }

                Text {
                    x: 0
                    y: 20
                    text: modelData.value
                    color: modelData.mint ? Theme.accentMint : "#FFFFFF"
                    font.pixelSize: 26
                    font.weight: Font.Bold
                }

                Text {
                    x: 62
                    y: 36
                    text: modelData.unit
                    color: Theme.heroLabel
                    font.pixelSize: 13
                    visible: modelData.unit.length > 0
                }
            }
        }

        Rectangle {
            id: cycleTrack
            x: 28
            y: 140
            width: hero.width - 56
            height: 4
            radius: 2
            color: Theme.darkCardSoft

            Rectangle {
                width: cycleTrack.width * Engine.progress
                height: 4
                radius: 2
                color: Theme.accentMint
            }
        }

        Text {
            x: 28
            y: 152
            text: Engine.nextSyncText
            color: Theme.heroMuted
            font.pixelSize: 11
        }
    }

    // -------- KPI cards
    Repeater {
        model: [
            {
                title: "时钟偏差",
                value: Engine.offsetText,
                sub: "阈值 ±" + Engine.warnMs + " ms",
                color: Theme.ink,
                tag: Engine.stateTone === "green" ? "良好" : (Engine.stateTone === "amber" ? "偏高" : "超限"),
                tone: Engine.stateTone
            },
            {
                title: "往返延迟",
                value: Engine.delayText,
                sub: Engine.prevDelayText,
                color: Theme.ink,
                tag: Engine.delayMs > 120 ? "偏高" : "稳定",
                tone: Engine.delayMs > 120 ? "amber" : "green"
            },
            {
                title: "累计校时",
                value: Engine.totalSyncs + " 次",
                sub: "今日 " + Engine.todaySyncs + " 次",
                color: Theme.blue,
                tag: "正常",
                tone: "blue"
            }
        ]

        delegate: AppCard {
            x: index * ((page.width - 32) / 3 + 16)
            y: 296
            width: (page.width - 32) / 3
            height: 96

            Text {
                x: 18
                y: 16
                text: modelData.title
                color: Theme.muted
                font.pixelSize: 12
            }

            Text {
                x: 18
                y: 38
                text: modelData.value
                color: modelData.color
                font.pixelSize: 22
                font.weight: Font.Bold
            }

            Text {
                x: 18
                y: 70
                text: modelData.sub
                color: Theme.muted
                font.pixelSize: 11
            }

            Pill {
                x: parent.width - width - 18
                y: 14
                text: modelData.tag
                tone: modelData.tone
            }
        }
    }

    // -------- source overview
    AppCard {
        y: 412
        width: parent.width
        height: 264

        Text {
            x: 20
            y: 18
            text: "时钟源概览"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 130
            y: 22
            text: "按优先级择优"
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
                { text: "时钟源", x: 20 },
                { text: "地址", x: 260 },
                { text: "层级", x: 430 },
                { text: "偏差", x: 510 },
                { text: "状态", x: 620 }
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
            model: Engine.overview

            delegate: Item {
                y: 84 + index * 44
                width: parent.width
                height: 44

                Rectangle {
                    x: 20
                    y: 43
                    width: parent.width - 40
                    height: 1
                    color: Theme.rowLine
                    visible: index < Engine.overview.length - 1
                }

                Rectangle {
                    x: 20
                    y: 16
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.tone(modelData.tone)
                }

                Text {
                    x: 38
                    y: 7
                    width: 200
                    text: modelData.name
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    x: 38
                    y: 26
                    width: 200
                    text: modelData.desc
                    color: Theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Text {
                    x: 260
                    y: 15
                    width: 160
                    text: modelData.host
                    color: Theme.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    x: 430
                    y: 15
                    text: modelData.stratum
                    color: Theme.ink
                    font.pixelSize: 12
                }

                Text {
                    x: 510
                    y: 15
                    width: 90
                    text: modelData.offset
                    color: Theme.tone(modelData.tone)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Pill {
                    x: 620
                    y: 12
                    text: modelData.status
                    tone: modelData.tone
                }
            }
        }
    }

    Popup {
        id: advanced
        focus: true
        width: 440
        modal: true
        anchors.centerIn: parent
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.card
            radius: 12
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 440
            implicitHeight: 232

            Text {
                x: 24
                y: 18
                text: "高级同步信息"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Column {
                x: 24
                y: 52
                spacing: 10

                Repeater {
                    model: [
                        { k: "主时钟源", v: Engine.primaryName },
                        { k: "服务器", v: Engine.serverHost + ":" + Engine.serverPort },
                        { k: "轮询周期", v: Engine.pollSec + " 秒 / 128 秒步进" },
                        { k: "择优策略", v: Engine.strategy },
                        { k: "偏差阈值", v: "±" + Engine.warnMs + " ms（严重 ±" + Engine.severeMs + " ms）" }
                    ]

                    delegate: Row {
                        spacing: 12
                        Text {
                            width: 96
                            text: modelData.k
                            color: Theme.muted
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData.v
                            color: Theme.ink
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Row {
                x: 24
                y: 182
                spacing: 12

                AppButton {
                    text: "打开服务器配置"
                    width: 132
                    primary: true
                    onClicked: {
                        advanced.close()
                        page.requestPage(5)
                    }
                }

                AppButton {
                    text: "关闭"
                    onClicked: advanced.close()
                }
            }
        }
    }
}
