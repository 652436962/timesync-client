import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    property string filterResult: "全部"

    function two(n) { return n < 10 ? "0" + n : "" + n }

    function timeLabels() {
        const now = new Date()
        const out = []
        for (let i = 0; i < 4; ++i) {
            const t = new Date(now.getTime() - (3 - i) * 3600 * 1000)
            out.push(two(t.getHours()) + ":" + two(t.getMinutes()))
        }
        return out
    }

    function filteredRecords() {
        const all = Engine.records
        if (filterResult === "全部")
            return all
        return all.filter(function (r) {
            return filterResult === "成功" ? r.result === "成功" : r.result === "降级"
        })
    }

    PageHeader {
        width: parent.width
        title: "同步历史"
        subtitle: "最近 7 天本机校时记录，共 " + Engine.totalSyncs + " 次"
        actions: [
            { label: "导出 CSV", key: "export" },
            { label: "筛选", key: "filter" }
        ]
        onAction: (key) => {
            if (key === "export")
                Engine.exportCsv()
            else
                filterMenu.open()
        }
    }

    AppCard {
        y: 108
        width: parent.width
        height: 300

        Text {
            x: 20
            y: 18
            text: "校时记录"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 98
            y: 22
            text: "按时间倒序"
            color: Theme.muted
            font.pixelSize: 11
        }

        Text {
            x: 20
            y: 44
            text: "偏差变化（ms）"
            color: Theme.muted
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        LineChart {
            x: 20
            y: 58
            width: parent.width - 40
            height: 196
            values: Engine.samples
            axisLabels: page.timeLabels()
        }

        Text {
            x: 20
            y: parent.height - 26
            text: Engine.samples.length > 1
                  ? "共 " + Engine.samples.length + " 个采样点 · 每 " + Engine.sampleInterval + " 秒采样"
                  : "等待采样数据…"
            color: Theme.faint
            font.pixelSize: 10
        }
    }

    AppCard {
        y: 428
        width: parent.width
        height: 250

        Text {
            x: 20
            y: 18
            text: "最近同步"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 98
            y: 22
            text: "最近 6 条"
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
                { text: "时间", x: 20 },
                { text: "触发方式", x: 130 },
                { text: "时钟源", x: 270 },
                { text: "偏差", x: 470 },
                { text: "延迟", x: 550 },
                { text: "结果", x: 640 }
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
            model: page.filteredRecords().slice(0, 6)

            delegate: Item {
                y: 82 + index * 27
                width: parent.width
                height: 27

                Rectangle {
                    x: 20
                    y: 26
                    width: parent.width - 40
                    height: 1
                    color: Theme.rowLine
                }

                Text {
                    x: 20
                    y: 8
                    text: modelData.time
                    color: Theme.ink
                    font.pixelSize: 12
                }

                Text {
                    x: 130
                    y: 8
                    text: modelData.trigger
                    color: Theme.muted
                    font.pixelSize: 12
                }

                Text {
                    x: 270
                    y: 8
                    width: 180
                    text: modelData.source
                    color: Theme.ink
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    x: 470
                    y: 8
                    width: 70
                    text: modelData.offset
                    color: Theme.tone(modelData.tone)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    x: 550
                    y: 8
                    text: modelData.delay
                    color: Theme.muted
                    font.pixelSize: 12
                }

                Pill {
                    x: 640
                    y: 5
                    text: modelData.result
                    tone: modelData.tone
                }
            }
        }

        Text {
            x: 20
            y: parent.height - 34
            visible: page.filteredRecords().length === 0
            text: "暂无记录，等待下一次步进校时（每 128 秒）"
            color: Theme.faint
            font.pixelSize: 11
        }
    }

    Popup {
        id: filterMenu
        focus: true
        x: page.width - 180
        y: 132
        width: 150
        padding: 6
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
                model: ["全部", "成功", "降级"]

                delegate: Rectangle {
                    width: 138
                    height: 32
                    radius: 7
                    color: hover.containsMouse ? Theme.hover : "transparent"

                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: page.filterResult === modelData ? Theme.green : Theme.ink
                        font.pixelSize: 12
                    }

                    HoverHandler { id: hover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.filterResult = modelData
                            filterMenu.close()
                        }
                    }
                }
            }
        }
    }
}
