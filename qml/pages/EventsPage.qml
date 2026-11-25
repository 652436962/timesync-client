import QtQuick
import QtQuick.Controls
import TimeSync

Item {
    id: page

    property string filter: "全部"
    property var currentEvent: ({})

    function todayText() {
        const d = new Date()
        const m = d.getMonth() + 1
        const day = d.getDate()
        return "今天 · " + d.getFullYear() + "-" + (m < 10 ? "0" + m : m) + "-" + (day < 10 ? "0" + day : day)
    }

    function filteredEvents() {
        const list = Engine.events
        if (filter === "全部")
            return list
        if (filter === "告警")
            return list.filter(function (e) { return e.level === "WARN" || e.level === "ERROR" })
        if (filter === "降级")
            return list.filter(function (e) { return e.title.indexOf("降级") >= 0 })
        return list.filter(function (e) {
            return e.level === "INFO" && e.title.indexOf("降级") < 0
        })
    }

    PageHeader {
        width: parent.width
        title: "事件日志"
        subtitle: "全部同步事件与系统告警，共 " + Engine.unreadCount + " 条未读"
        actions: [
            { label: "清空", key: "clear" },
            { label: "导出日志", key: "export" }
        ]
        onAction: (key) => {
            if (key === "export")
                Engine.exportEvents()
            else if (Engine.eventCount > 0)
                clearDialog.open()
        }
    }

    AppCard {
        y: 108
        width: parent.width
        height: 44
        radius: 10

        Row {
            x: 14
            y: 12
            spacing: 8

            Repeater {
                model: [
                    { label: "全部", count: Engine.eventCount },
                    { label: "告警", count: Engine.warnCount },
                    { label: "降级", count: Engine.degradeCount },
                    { label: "成功", count: Engine.successCount }
                ]

                delegate: Rectangle {
                    width: (modelData.label + " " + modelData.count).length * 11 + 24
                    height: 20
                    radius: 10
                    color: page.filter === modelData.label ? Theme.greenSoft
                         : hover.containsMouse ? Theme.hover : (Theme.dark ? "#1B2522" : "#F3F6F5")

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label + " " + modelData.count
                        color: page.filter === modelData.label ? Theme.green : Theme.muted
                        font.pixelSize: 11
                        font.weight: page.filter === modelData.label ? Font.Medium : Font.Normal
                    }

                    HoverHandler { id: hover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.filter = modelData.label
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 14
            text: page.todayText()
            color: Theme.muted
            font.pixelSize: 11
        }
    }

    AppCard {
        y: 168
        width: parent.width
        height: 510

        Text {
            x: 20
            y: 18
            text: "事件列表"
            color: Theme.ink
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        ListView {
            id: list
            x: 0
            y: 52
            width: parent.width
            height: 458
            clip: true
            model: page.filteredEvents()
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                width: list.width
                height: 64

                Rectangle {
                    x: 20
                    y: 63
                    width: parent.width - 40
                    height: 1
                    color: Theme.rowLine
                }

                Pill {
                    x: 20
                    y: 17
                    text: modelData.level
                    tone: modelData.tone
                    fontSize: 9
                }

                Text {
                    x: 90
                    y: 20
                    text: modelData.time
                    color: Theme.muted
                    font.pixelSize: 11
                }

                Text {
                    x: 176
                    y: 12
                    width: parent.width - 360
                    text: modelData.title
                    color: Theme.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    x: 176
                    y: 33
                    width: parent.width - 380
                    text: modelData.desc
                    color: Theme.muted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Rectangle {
                    x: parent.width - 52
                    y: 28
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.red
                    visible: modelData.unread
                }

                Text {
                    x: parent.width - 120
                    y: 20
                    text: "详情 ›"
                    color: Theme.green
                    font.pixelSize: 11
                    font.weight: Font.Medium

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.currentEvent = modelData
                            Engine.markRead(modelData.index)
                            detail.open()
                        }
                    }
                }
            }
        }

        Text {
            x: 20
            y: 80
            visible: page.filteredEvents().length === 0
            text: "当前筛选条件下没有事件"
            color: Theme.faint
            font.pixelSize: 12
        }
    }

    Popup {
        id: detail
        focus: true
        width: 460
        height: 236
        modal: true
        anchors.centerIn: parent
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.card
            radius: 12
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 460
            implicitHeight: 236

            Row {
                x: 24
                y: 18
                spacing: 10

                Pill {
                    text: page.currentEvent.level || "INFO"
                    tone: page.currentEvent.tone || "green"
                    fontSize: 9
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.currentEvent.full || ""
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }

            Text {
                x: 24
                y: 56
                width: 412
                text: page.currentEvent.title || ""
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                x: 24
                y: 88
                width: 412
                height: 80
                text: page.currentEvent.desc || ""
                color: Theme.muted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            AppButton {
                x: 24
                y: 184
                text: "关闭"
                onClicked: detail.close()
            }

            AppButton {
                x: 132
                y: 184
                text: "标记全部已读"
                width: 120
                primary: true
                onClicked: {
                    Engine.markAllRead()
                    detail.close()
                }
            }
        }
    }

    Popup {
        id: clearDialog
        focus: true
        width: 380
        height: 168
        modal: true
        anchors.centerIn: parent

        background: Rectangle {
            color: Theme.card
            radius: 12
            border.width: 1
            border.color: Theme.border
        }

        contentItem: Item {
            implicitWidth: 380
            implicitHeight: 168

            Text {
                x: 24
                y: 20
                text: "清空事件日志？"
                color: Theme.ink
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                x: 24
                y: 52
                width: 332
                text: "此操作不可撤销，将删除本机保存的 " + Engine.eventCount + " 条事件。"
                color: Theme.muted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Row {
                x: 24
                y: 112
                spacing: 12

                AppButton {
                    text: "清空"
                    primary: true
                    width: 96
                    onClicked: {
                        Engine.clearEvents()
                        clearDialog.close()
                    }
                }

                AppButton {
                    text: "取消"
                    onClicked: clearDialog.close()
                }
            }
        }
    }
}
