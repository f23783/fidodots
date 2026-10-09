import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

PanelWindow {
    id: root

    property bool isOpen: false

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 32

    anchors.top: true

    margins {
        top: 56
    }

    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: isOpen

    IpcHandler {
        target: "panel"
        function toggle(): void {
            root.isOpen = !root.isOpen
        }
    }

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.isOpen
        onActiveChanged: if (!active) root.isOpen = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Colors.base.r, Colors.base.g, Colors.base.b, 0.95)
        border.color: Colors.pillBorder
        border.width: 1
    }

    ColumnLayout {
        id: col
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 12

        QuickSettings {}
        CalendarWidget {}
        SystemInfo {}
        MusicControl {}
    }
}
