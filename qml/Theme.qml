pragma Singleton
import QtQuick

QtObject {
    id: theme

    readonly property bool dark: Engine.themeMode === "深色"
                                 || (Engine.themeMode === "跟随系统" && Engine.systemDark)

    readonly property color bg: dark ? "#0F1513" : "#F5F7F6"
    readonly property color card: dark ? "#17201D" : "#FFFFFF"
    readonly property color border: dark ? "#2A3531" : "#E3E8E6"
    readonly property color ink: dark ? "#E9F0ED" : "#16211E"
    readonly property color muted: dark ? "#9AA9A3" : "#5F6E69"
    readonly property color green: dark ? "#57B79B" : "#1F6F5C"
    readonly property color greenSoft: dark ? "#17332B" : "#E7F3EF"
    readonly property color amber: dark ? "#D9A34A" : "#C9861F"
    readonly property color amberSoft: dark ? "#33291A" : "#FBF2E2"
    readonly property color red: dark ? "#D47366" : "#C2483C"
    readonly property color redSoft: dark ? "#33211E" : "#FAEAE8"
    readonly property color blue: dark ? "#6F9ADB" : "#2C5FA8"
    readonly property color blueSoft: dark ? "#1B2738" : "#E8EFF9"
    readonly property color tableHead: dark ? "#1B2522" : "#FAFBFB"
    readonly property color rowLine: dark ? "#232D2A" : "#F0F3F2"
    readonly property color hover: dark ? "#1C2623" : "#F3F6F5"
    readonly property color track: dark ? "#3A4642" : "#D7DEDC"
    readonly property color navIcon: dark ? "#5A6863" : "#B9C4C1"
    readonly property color fieldBg: dark ? "#131B19" : "#FAFBFB"
    readonly property color faint: dark ? "#82918C" : "#A9B5B1"
    readonly property color darkCard: "#0E3A31"
    readonly property color darkCardSoft: "#1D6B58"
    readonly property color heroText: "#FFFFFF"
    readonly property color heroMuted: "#A8CEC4"
    readonly property color heroLabel: "#9FC7BC"
    readonly property color accentMint: "#7FE3C2"

    readonly property string fontFamily: "Inter"

    function tone(name) {
        switch (name) {
        case "green": return green
        case "amber": return amber
        case "red": return red
        case "blue": return blue
        case "muted": return muted
        default: return ink
        }
    }

    function toneSoft(name) {
        switch (name) {
        case "green": return greenSoft
        case "amber": return amberSoft
        case "red": return redSoft
        case "blue": return blueSoft
        default: return dark ? "#232C29" : "#F0F3F2"
        }
    }
}
