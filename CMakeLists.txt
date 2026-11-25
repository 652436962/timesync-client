cmake_minimum_required(VERSION 3.21)
project(timesync-client VERSION 2.4.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Network Widgets)

qt_standard_project_setup()

qt_add_executable(timesync-client
    src/main.cpp
    src/ntpprobe.cpp
    src/ntpprobe.h
    src/synccore.cpp
    src/synccore.h
)

qt_add_resources(timesync-client "fonts"
    PREFIX "/fonts"
    BASE assets/fonts
    FILES
        assets/fonts/Inter-Regular.ttf
        assets/fonts/Inter-Medium.ttf
        assets/fonts/Inter-SemiBold.ttf
        assets/fonts/Inter-Bold.ttf
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(timesync-client
    URI TimeSync
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/TitleBar.qml
        qml/Sidebar.qml
        qml/StatusBar.qml
        qml/Toast.qml
        qml/components/AppButton.qml
        qml/components/AppCard.qml
        qml/components/CheckBoxItem.qml
        qml/components/ComboRow.qml
        qml/components/LineChart.qml
        qml/components/PageHeader.qml
        qml/components/ParamSlider.qml
        qml/components/Pill.qml
        qml/components/RadioDot.qml
        qml/components/Toggle.qml
        qml/components/TrendChart.qml
        qml/pages/ConnectionPage.qml
        qml/pages/SourcesPage.qml
        qml/pages/HistoryPage.qml
        qml/pages/DriftPage.qml
        qml/pages/EventsPage.qml
        qml/pages/ServerPage.qml
        qml/pages/AlertsPage.qml
        qml/pages/PrefsPage.qml
)

target_link_libraries(timesync-client PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::Widgets
)

install(TARGETS timesync-client
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
