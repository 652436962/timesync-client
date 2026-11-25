import QtQuick
import TimeSync

Item {
    id: chart

    property var values: []
    property int warnMs: 5
    property var axisLabels: []

    onValuesChanged: canvas.requestPaint()
    onWarnMsChanged: canvas.requestPaint()
    onAxisLabelsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.clearRect(0, 0, w, h)
            if (w < 60 || h < 60)
                return

            const left = 32
            const right = 8
            const top = 14
            const bottom = h - 28
            const cw = w - left - right
            const ch = bottom - top
            const mid = top + ch / 2

            let peak = chart.warnMs
            for (let i = 0; i < chart.values.length; ++i)
                peak = Math.max(peak, Math.abs(chart.values[i]) * 1.25)
            const range = Math.max(5, Math.ceil(peak / 5) * 5)
            const yFor = function (v) { return mid - (v / range) * (ch / 2) }

            // Tolerance band
            const band = (chart.warnMs / range) * (ch / 2)
            ctx.fillStyle = String(Theme.hover)
            ctx.fillRect(left, mid - band, cw, band * 2)
            ctx.strokeStyle = String(Theme.border)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(left, mid - band + 0.5)
            ctx.lineTo(left + cw, mid - band + 0.5)
            ctx.moveTo(left, mid + band + 0.5)
            ctx.lineTo(left + cw, mid + band + 0.5)
            ctx.stroke()

            // Zero line
            ctx.strokeStyle = String(Theme.navIcon)
            ctx.beginPath()
            ctx.moveTo(left, mid + 0.5)
            ctx.lineTo(left + cw, mid + 0.5)
            ctx.stroke()

            // Axis labels
            ctx.font = "10px Inter"
            ctx.fillStyle = String(Theme.muted)
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            ctx.fillText("+" + range, left - 8, top + 2)
            ctx.fillText("0", left - 8, mid)
            ctx.fillText("-" + range, left - 8, bottom - 2)

            const vals = chart.values
            if (vals.length === 0)
                return

            const bars = Math.min(60, vals.length)
            const start = vals.length - bars
            const barW = cw / bars
            for (let i = 0; i < bars; ++i) {
                const v = vals[start + i]
                const zero = mid
                const y = yFor(v)
                const hgt = Math.max(2, Math.abs(y - zero))
                const over = Math.abs(v) > chart.warnMs
                ctx.fillStyle = String(over ? Theme.amber : Theme.green)
                const x = left + i * barW
                const yTop = v >= 0 ? zero - hgt : zero
                ctx.fillRect(x + 0.5, yTop, Math.max(1.5, barW - 1.6), hgt)
            }

            // Time labels
            ctx.fillStyle = String(Theme.muted)
            ctx.textBaseline = "top"
            const labels = chart.axisLabels
            for (let i = 0; i < labels.length; ++i) {
                const x = left + (i / (labels.length - 1)) * cw
                const tw = ctx.measureText(labels[i]).width
                if (i === 0) {
                    ctx.textAlign = "left"
                    ctx.fillText(labels[i], x, bottom + 10)
                } else if (i === labels.length - 1) {
                    ctx.textAlign = "right"
                    ctx.fillText(labels[i], x, bottom + 10)
                } else {
                    ctx.textAlign = "center"
                    ctx.fillText(labels[i], x, bottom + 10)
                }
            }
        }
    }
}
