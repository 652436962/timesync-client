import QtQuick
import TimeSync

Item {
    id: page

    function two(n) { return n < 10 ? "0" + n : "" + n }

    function timeLabels() {
        const now = new Date()
        const out = []
        for (let i = 0; i < 5; ++i) {
            const t = new Date(now.getTime() - (4 - i) * 30 * 60 * 1000)
            out.push(two(t.getHours()) + ":" + two(t.getMinutes()))
        }
        return out
    }

    PageHeader {
        width: parent.width
        title: "偏差监控"
        subtitle: "实时监控本机时钟偏移与抖动，超出阈值即告警"
        actions: [
            { label: Engine.paused ? "继续监控" : "暂停监控", key: "pause" }
        ]
        onAction: (key) => {
            if (key === "pause")
                Engine.paused = !Engine.paused
        }
    }

    Repeater {
        model: [
            {
                title: "当前偏差",
                value: Engine.offsetText,
                sub: "阈值 ±" + Engine.warnMs + " ms",
                color: Theme.tone(Engine.stateTone),
                tag: Engine.stateTone === "green" ? "正常" : (Engine.stateTone === "amber" ? "偏高" : "超限"),
                tone: Engine.stateTone
            },
            {
                title: "最大偏差",
                value: Engine.maxDeviationText,
                sub: "近 2 小时采样",
                color: Theme.amber,
                tag: Engine.maxDeviationMs > Engine.warnMs ? "已恢复" : "平稳",
                tone: Engine.maxDeviationMs > Engine.warnMs ? "amber" : "green"
            },
            {
                title: "时钟抖动",
                value: Engine.jitterText,
                sub: "最近 20 个样本",
                color: Theme.green,
                tag: Engine.jitterMs < 1 ? "平稳" : "波动",
                tone: Engine.jitterMs < 1 ? "green" : "amber"
            }
        ]

        delegate: AppCard {
            x: index * ((page.width - 32) / 3 + 16)
            y: 108
            width: (page.width - 32) / 3
            height: 108

            Text {
                x: 18
                y: 16
                text: modelData.title
                color: Theme.muted
                font.pixelSize: 12
            }

            Text {
                x: 18
                y: 40
                text: modelData.value
                color: modelData.color
                font.pixelSize: 26
                font.weight: Font.Bold
            }

            Text {
                x: 18
                y: 78
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

    AppCard {
        y: 236
        width: parent.width
        height: 300

        Text {
            x: 20
            y: 18
            text: "偏差趋势"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 96
            y: 22
            text: Engine.samplingText
            color: Theme.muted
            font.pixelSize: 11
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 22
            spacing: 8

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "实测偏差"
                color: Theme.muted
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: Theme.navIcon
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "容差带 ±" + Engine.warnMs + " ms"
                color: Theme.muted
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TrendChart {
            x: 56
            y: 48
            width: parent.width - 96
            height: 224
            values: Engine.samples
            warnMs: Engine.warnMs
            axisLabels: page.timeLabels()
        }

        Text {
            x: parent.width - 260
            y: parent.height - 22
            text: "采样 " + Engine.sampleInterval + " 秒 · 缓冲 " + Engine.sampleCount + " 点"
            color: Theme.faint
            font.pixelSize: 10
        }
    }

    AppCard {
        y: 548
        width: parent.width
        height: 130

        Text {
            x: 20
            y: 18
            text: "告警阈值"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            x: 96
            y: 22
            text: "超限后客户端会记录事件并弹窗提示"
            color: Theme.muted
            font.pixelSize: 11
        }

        ParamSlider {
            x: 20
            y: 54
            label: "警告阈值"
            valueText: "±" + Engine.warnMs + " ms"
            from: 1
            to: 20
            step: 1
            value: Engine.warnMs
            toneColor: Theme.amber
            onUserEdited: (v) => Engine.warnMs = Math.round(v)
        }

        ParamSlider {
            x: 316
            y: 54
            label: "严重阈值"
            valueText: "±" + Engine.severeMs + " ms"
            from: 10
            to: 200
            step: 5
            value: Engine.severeMs
            toneColor: Theme.red
            onUserEdited: (v) => Engine.severeMs = Math.round(v)
        }

        ParamSlider {
            x: 612
            y: 54
            label: "采样间隔"
            valueText: Engine.sampleInterval + " 秒"
            from: 1
            to: 30
            step: 1
            value: Engine.sampleInterval
            toneColor: Theme.green
            onUserEdited: (v) => Engine.sampleInterval = Math.round(v)
        }
    }
}
