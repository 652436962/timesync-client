import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: row

    property string label: ""
    property string value: ""
    property var options: []
    signal selected(string value)

    height: 44

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: Theme.ink
        font.pixelSize: 13
    }

    Text {
        anchors.right: chevron.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: row.value
        color: Theme.muted
        font.pixelSize: 12
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 280)
        horizontalAlignment: Text.AlignRight
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: Theme.faint
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.showAt(row)
    }

    Popup {
        id: menu
        focus: true
        width: 190
        padding: 6
        modal: false
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
                model: row.options

                delegate: Rectangle {
                    width: menu.width - 12
                    height: 34
                    radius: 7
                    color: hover.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: modelData === row.value ? Theme.green : Theme.ink
                        font.pixelSize: 12
                        font.weight: modelData === row.value ? Font.Medium : Font.Normal
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✓"
                        visible: modelData === row.value
                        color: Theme.green
                        font.pixelSize: 11
                    }

                    HoverHandler { id: hover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            row.selected(modelData)
                            menu.close()
                        }
                    }
                }
            }
        }

        function showAt(item) {
            const p = item.mapToItem(null, 0, 0)
            const winH = item.Window.window ? item.Window.window.height : 760
            x = Math.max(8, item.width - width)
            y = (p.y + item.height + height + 8 > winH) ? -height - 2 : item.height + 2
            open()
        }
    }
}
