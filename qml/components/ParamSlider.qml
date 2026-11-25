import QtQuick
import TimeSync

Item {
    id: slider

    property string label: ""
    property string valueText: ""
    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property color toneColor: Theme.green
    signal userEdited(real value)

    width: 240
    height: 46

    function ratio() {
        if (to <= from)
            return 0
        return Math.max(0, Math.min(1, (value - from) / (to - from)))
    }

    function setFromX(px) {
        const r = Math.max(0, Math.min(1, px / track.width))
        let v = from + r * (to - from)
        v = Math.round(v / step) * step
        v = Math.max(from, Math.min(to, v))
        if (v !== value) {
            value = v
            slider.userEdited(v)
        }
    }

    Text {
        text: slider.label
        color: Theme.ink
        font.pixelSize: 12
        font.weight: Font.Medium
        y: 0
    }

    Text {
        x: 190
        y: 0
        width: 50
        text: slider.valueText
        color: slider.toneColor
        font.pixelSize: 12
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignRight
    }

    Rectangle {
        id: track
        y: 30
        width: 240
        height: 4
        radius: 2
        color: Theme.dark ? "#2A3531" : "#E8EDEC"

        Rectangle {
            width: Math.max(0, slider.ratio() * track.width)
            height: 4
            radius: 2
            color: slider.toneColor
        }
    }

    Rectangle {
        id: knob
        x: slider.ratio() * track.width - 7
        y: 23
        width: 14
        height: 14
        radius: 7
        color: Theme.card
        border.width: 2
        border.color: slider.toneColor
    }

    MouseArea {
        x: 0
        y: 14
        width: 240
        height: 30
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => slider.setFromX(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) slider.setFromX(mouse.x) }
    }
}
