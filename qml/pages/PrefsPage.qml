import QtQuick
import TimeSync

Item {
    id: page

    PageHeader {
        width: parent.width
        title: "偏好设置"
        subtitle: "外观、启动行为与数据保留策略"
    }

    // -------- appearance
    AppCard {
        y: 108
        width: parent.width
        height: 178

        Text {
            x: 20
            y: 14
            text: "外观"
            color: Theme.ink
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        ComboRow {
            x: 20
            y: 44
            width: parent.width - 40
            label: "主题"
            value: Engine.themeMode
            options: ["跟随系统", "浅色", "深色"]
            onSelected: (v) => Engine.themeMode = v
        }

        Rectangle {
            x: 20
            y: 76
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        Item {
            x: 20
            y: 88
            width: parent.width - 40
            height: 44

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "强调色"
                color: Theme.ink
                font.pixelSize: 13
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 38
                anchors.verticalCenter: parent.verticalCenter
                text: "时钟绿 #1F6F5C"
                color: Theme.muted
                font.pixelSize: 12
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Theme.green
            }
        }

        Rectangle {
            x: 20
            y: 120
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        ComboRow {
            x: 20
            y: 132
            width: parent.width - 40
            label: "界面密度"
            value: Engine.density
            options: ["紧凑", "舒适"]
            onSelected: (v) => Engine.density = v
        }
    }

    // -------- startup
    AppCard {
        y: 298
        width: parent.width
        height: 178

        Text {
            x: 20
            y: 14
            text: "启动与运行"
            color: Theme.ink
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            x: 20
            y: 48
            text: "开机自启动"
            color: Theme.ink
            font.pixelSize: 13
        }

        Toggle {
            x: parent.width - 58
            y: 44
            checked: Engine.autostart
            onToggled: (v) => Engine.autostart = v
        }

        Rectangle {
            x: 20
            y: 76
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        Text {
            x: 20
            y: 92
            text: "最小化到托盘"
            color: Theme.ink
            font.pixelSize: 13
        }

        Toggle {
            x: parent.width - 58
            y: 88
            checked: Engine.trayEnabled
            onToggled: (v) => Engine.trayEnabled = v
        }

        Rectangle {
            x: 20
            y: 120
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        ComboRow {
            x: 20
            y: 132
            width: parent.width - 40
            label: "关闭窗口时"
            value: Engine.closeAction
            options: ["退出程序", "最小化到托盘"]
            onSelected: (v) => Engine.closeAction = v
        }
    }

    // -------- data & privacy
    AppCard {
        y: 488
        width: parent.width
        height: 178

        Text {
            x: 20
            y: 14
            text: "数据与隐私"
            color: Theme.ink
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        ComboRow {
            x: 20
            y: 44
            width: parent.width - 40
            label: "日志保留"
            value: Engine.logRetention
            options: ["最近 7 天", "最近 30 天", "最近 90 天", "永久保留"]
            onSelected: (v) => Engine.logRetention = v
        }

        Rectangle {
            x: 20
            y: 76
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        Text {
            x: 20
            y: 92
            text: "同步上报"
            color: Theme.ink
            font.pixelSize: 13
        }

        Text {
            x: 88
            y: 93
            text: Engine.uploadEnabled ? "开启 · 仅上传匿名统计数据" : "关闭 · 不上传任何数据"
            color: Theme.muted
            font.pixelSize: 11
        }

        Toggle {
            x: parent.width - 58
            y: 88
            checked: Engine.uploadEnabled
            onToggled: (v) => Engine.uploadEnabled = v
        }

        Rectangle {
            x: 20
            y: 120
            width: parent.width - 40
            height: 1
            color: Theme.rowLine
        }

        Text {
            x: 20
            y: 135
            text: "导出配置"
            color: Theme.ink
            font.pixelSize: 13
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 44
            y: 135
            text: "备份为 JSON 文件"
            color: Theme.muted
            font.pixelSize: 12
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 132
            text: "›"
            color: Theme.faint
            font.pixelSize: 15
        }

        MouseArea {
            x: 0
            y: 128
            width: parent.width
            height: 34
            cursorShape: Qt.PointingHandCursor
            onClicked: Engine.exportConfig()
        }

        Text {
            x: 20
            y: 158
            text: Engine.versionLine
            color: Theme.muted
            font.pixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 158
            text: "检查更新 ›"
            color: Theme.green
            font.pixelSize: 11
            font.weight: Font.Medium

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Engine.checkUpdates()
            }
        }
    }
}
