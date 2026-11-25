import QtQuick
import TimeSync

Item {
    id: chart

    property var values: []
    property var axisLabels: []

    onValuesChanged: canvas.requestPaint()
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
            if (w < 40 || h < 40)
                return

            const left = 34
            const right = 8
            const top = 16
            const bottom = h - 30
            const cw = w - left - right
            const ch = bottom - top

            let peak = 2
            for (let i = 0; i < chart.values.length; ++i)
                peak = Math.max(peak, Math.abs(chart.values[i]) * 1.15)
            const yMax = Math.ceil(peak)

            ctx.lineWidth = 1
            ctx.strokeStyle = String(Theme.rowLine)
            ctx.font = "10px Inter"
            ctx.fillStyle = String(Theme.muted)
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"

            for (let g = 0; g <= yMax; ++g) {
                const y = bottom - (g / yMax) * ch
                ctx.beginPath()
                ctx.moveTo(left, y + 0.5)
                ctx.lineTo(left + cw, y + 0.5)
                ctx.stroke()
                if (g % Math.ceil(yMax / 2) === 0 || g === yMax) {
                    ctx.fillText(g === 0 ? "0" : "+" + g, left - 10, y)
                }
            }

            const vals = chart.values
            if (vals.length === 0)
                return

            const points = 13
            let pts = []
            const span = Math.min(vals.length, 200)
            const start = vals.length - span
            for (let i = 0; i < points; ++i) {
                const idx = span <= 1 ? start : start + Math.round(i * (span - 1) / (points - 1))
                const v = Math.max(0, Math.min(vals[idx], yMax))
                const x = left + (i / (points - 1)) * cw
                const y = bottom - (v / yMax) * ch
                pts.push({ x: x, y: y })
            }

            ctx.strokeStyle = String(Theme.green)
            ctx.lineWidth = 1.6
            ctx.setLineDash([2.5, 3.2])
            ctx.beginPath()
            for (let i = 0; i < pts.length; ++i) {
                if (i === 0)
                    ctx.moveTo(pts[i].x, pts[i].y)
                else
                    ctx.lineTo(pts[i].x, pts[i].y)
            }
            ctx.stroke()
            ctx.setLineDash([])

            ctx.fillStyle = String(Theme.green)
            for (let i = 0; i < pts.length; ++i) {
                ctx.beginPath()
                ctx.arc(pts[i].x, pts[i].y, 2.6, 0, Math.PI * 2)
                ctx.fill()
            }

            ctx.fillStyle = String(Theme.muted)
            ctx.textAlign = "left"
            ctx.textBaseline = "top"
            const labels = chart.axisLabels.length ? chart.axisLabels : ["", "", "", ""]
            for (let i = 0; i < labels.length; ++i) {
                const x = left + (i / (labels.length - 1)) * cw
                if (i === 0)
                    ctx.fillText(labels[i], x, bottom + 12)
                else if (i === labels.length - 1)
                    ctx.fillText(labels[i], x - ctx.measureText(labels[i]).width, bottom + 12)
                else
                    ctx.fillText(labels[i], x - ctx.measureText(labels[i]).width / 2, bottom + 12)
            }
        }
    }
}
