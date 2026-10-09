import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root

    property bool panelVisible: true

    spacing: 8
    Layout.fillWidth: true

    function refreshState() {
        if (!muteRead.running)
            muteRead.running = true
        if (!volInit.running)
            volInit.running = true
        if (!brightInit.running)
            brightInit.running = true
    }

    onPanelVisibleChanged: {
        if (panelVisible)
            refreshState()
    }

    Component.onCompleted: refreshState()

    Text {
        text: "Quick Settings"
        color: Colors.textMuted
        font.pixelSize: 11
        font.weight: Font.Medium
        leftPadding: 4
    }

    RowLayout {
        spacing: 8
        Layout.fillWidth: true

        TogglePill {
            icon: "\uf1eb"
            label: "WiFi"
            active: Networking.wifiEnabled
            onToggleRequested: function(desired) {
                Networking.wifiEnabled = desired
            }
        }

        TogglePill {
            icon: "\uf294"
            label: "Bluetooth"
            active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
            enabled: Bluetooth.defaultAdapter !== null
            onToggleRequested: function(desired) {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = desired
            }
        }

        TogglePill {
            id: muteToggle
            icon: active ? "\udb81\udf5f" : "\udb81\udd7e"
            label: "Silent"
            busy: muteProc.running
            onToggleRequested: function(desired) {
                muteProc.command = ["pactl", "set-sink-mute", "@DEFAULT_SINK@", desired ? "1" : "0"]
                muteProc.running = true
            }
        }
    }

    Process {
        id: muteProc
        command: []
        onExited: muteRead.running = true
    }

    Process {
        id: muteRead
        command: ["bash", "-c", "pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: muteToggle.active = text.trim() === "1"
        }
    }

    // Dışarıdan yapılan değişiklikleri düzenli olarak panele yansıt.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshState()
    }

    // Ses slider
    SliderRow {
        id: volSlider
        icon: "\udb81\udd7e"
        Layout.fillWidth: true
        onMoved: function(v) {
            volCmd.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", Math.round(v) + "%"]
            volCmd.running = true
        }
    }

    Process { id: volCmd; command: [] }

    Process {
        id: volInit
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseFloat(text.trim())
                if (!isNaN(value))
                    volSlider.value = value
            }
        }
    }

    // Parlaklık slider
    SliderRow {
        id: brightSlider
        icon: "\udb80\udce0"
        Layout.fillWidth: true
        onMoved: function(v) {
            brightCmd.command = ["swayosd-client", "--brightness", Math.round(v).toString()]
            brightCmd.running = true
        }
    }

    Process { id: brightCmd; command: [] }

    Process {
        id: brightInit
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseFloat(text.trim())
                if (!isNaN(value))
                    brightSlider.value = value
            }
        }
    }
}
