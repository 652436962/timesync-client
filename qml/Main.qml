import QtQuick
import QtQuick.Controls
import TimeSync

Window {
    id: root

    width: 1180
    height: 760
    minimumWidth: 1080
    minimumHeight: 700
    visible: true
    title: "TimeSync 时间同步客户端"
    color: Theme.bg
    flags: Qt.Window | Qt.FramelessWindowHint

    property int currentPage: Math.max(0, Math.min(7, InitialPage))

    function closeWindow() {
        if (Engine.hideOnClose)
            root.hide()
        else
            Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    TitleBar {
        id: titleBar
        width: parent.width
        height: 52
        onMinimizeRequested: root.showMinimized()
        onMaximizeRequested: {
            if (root.visibility === Window.Maximized)
                root.showNormal()
            else
                root.showMaximized()
        }
        onCloseRequested: root.closeWindow()
    }

    Sidebar {
        id: sidebar
        y: 52
        width: 208
        height: root.height - 52 - 30
        current: root.currentPage
        onNavigate: (index) => root.currentPage = index
    }

    StatusBar {
        id: statusBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 30
    }

    Loader {
        id: loader
        x: 240
        y: 52
        width: root.width - 240 - 32
        height: root.height - 52 - 30
        asynchronous: false

        sourceComponent: {
            switch (root.currentPage) {
            case 1: return sourcesPage
            case 2: return historyPage
            case 3: return driftPage
            case 4: return eventsPage
            case 5: return serverPage
            case 6: return alertsPage
            case 7: return prefsPage
            default: return connectionPage
            }
        }

        Connections {
            target: loader.item
            ignoreUnknownSignals: true
            function onRequestPage(index) { root.currentPage = index }
        }
    }

    Component { id: connectionPage; ConnectionPage {} }
    Component { id: sourcesPage; SourcesPage {} }
    Component { id: historyPage; HistoryPage {} }
    Component { id: driftPage; DriftPage {} }
    Component { id: eventsPage; EventsPage {} }
    Component { id: serverPage; ServerPage {} }
    Component { id: alertsPage; AlertsPage {} }
    Component { id: prefsPage; PrefsPage {} }

    Toast {
        id: toast
        x: root.width - width - 32
        y: root.height - 30 - height - 20
    }

    Connections {
        target: Engine
        function onToast(title, text, tone) {
            if (!ScreenshotMode)
                toast.show(title, text, tone)
        }
    }

    // Frameless window resize grip
    MouseArea {
        width: 16
        height: 16
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        property real startW: 0
        property real startH: 0

        onPressed: (mouse) => {
            startW = root.width
            startH = root.height
            mouse.accepted = true
        }

        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            root.width = Math.max(root.minimumWidth, startW + mouse.x)
            root.height = Math.max(root.minimumHeight, startH + mouse.y)
        }
    }
}
