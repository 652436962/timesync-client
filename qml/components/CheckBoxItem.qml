import QtQuick
import TimeSync

Item {
    id: cb

    property string label: ""
    property bool checked: false
    property bool interactive: true
    property color labelColor: Theme.ink
    signal toggled(bool value)

    implicitWidth: content.width
    implicitHeight: 20
    opacity: interactive ? 1.0 : 0.65

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 14
            height: 14
            radius: 3
            y: 3
            color: cb.checked ? Theme.green : "transparent"
            border.width: 1
            border.color: cb.checked ? Theme.green : Theme.navIcon

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "#FFFFFF"
                font.pixelSize: 9
                font.weight: Font.Bold
                visible: cb.checked
            }
        }

        Text {
            text: cb.label
            color: cb.labelColor
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: cb.interactive
        cursorShape: cb.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: cb.toggled(!cb.checked)
    }
}
