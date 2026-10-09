import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

PanelWindow {
    id: root

    property bool isOpen: false

    anchors.right: true
    anchors.top: true

    implicitWidth: 280
    implicitHeight: 580

    margins {
        top: 56
        right: 16
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"
    visible: isOpen

    // IPC
    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.isOpen = !root.isOpen
        }
    }

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.isOpen
        onActiveChanged: if (!active) root.isOpen = false
    }

    // Batarya verileri
    property int batCap: 0
    property bool charging: false
    property string powerProfile: "balanced"

    Process {
        id: batCapProc
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1 || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.batCap = parseInt(text.trim()) || 0
        }
    }
    Process {
        id: batStatusProc
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1 || echo 'Unknown'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.charging = text.trim() === "Charging"
        }
    }
    Process {
        id: profileProc
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo 'balanced'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = text.trim()
        }
    }
    Timer {
        interval: Config.batteryInterval; running: true; repeat: true
        onTriggered: { batCapProc.running = true; batStatusProc.running = true }
    }

    // Ana içerik
    Rectangle {
        anchors {
            fill: parent
            leftMargin: 8
            topMargin: 8
            bottomMargin: 8
            rightMargin: 0
        }
        radius: 20
        color: Qt.rgba(Colors.base.r, Colors.base.g, Colors.base.b, 0.96)
        border.color: Colors.pillBorder
        border.width: 1
        clip: true

        // Sağ üst köşe — kapat butonu
        Text {
            anchors { top: parent.top; right: parent.right; margins: 16 }
            text: "\uf2f5"
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 18
            color: Colors.textHint
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isOpen = false
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 20
                topMargin: 16
            }
            spacing: 20

            // ── Saat ─────────────────────────────
            RowLayout {
                spacing: 8

                // Saat bloğu
                Rectangle {
                    width: 58; height: 50; radius: 10
                    color: Colors.pillBg
                    border.color: Colors.pillBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 0
                        Text {
                            id: hrText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(new Date(), "hh")
                            font.pixelSize: 22; font.weight: Font.Bold
                            color: Colors.accent
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "HR"; font.pixelSize: 9; color: Colors.textHint
                        }
                    }
                }

                Text { text: ":"; font.pixelSize: 24; font.weight: Font.Bold; color: Colors.textHint }

                // Dakika bloğu
                Rectangle {
                    width: 58; height: 50; radius: 10
                    color: Colors.pillBg
                    border.color: Colors.pillBorder; border.width: 1
                    Column {
                        anchors.centerIn: parent; spacing: 0
                        Text {
                            id: minText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(new Date(), "mm")
                            font.pixelSize: 22; font.weight: Font.Bold
                            color: Colors.red
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MIN"; font.pixelSize: 9; color: Colors.textHint
                        }
                    }
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: {
                        hrText.text = Qt.formatTime(new Date(), "hh")
                        minText.text = Qt.formatTime(new Date(), "mm")
                    }
                }
            }

            // ── Dairesel Batarya ─────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 200; height: 200

                // Arka gölge halkası
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Colors.pillBorder
                        strokeWidth: 14
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 100; centerY: 100
                            radiusX: 82; radiusY: 82
                            startAngle: -230
                            sweepAngle: 280
                        }
                    }
                }

                // Batarya yüzde halkası
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeWidth: 14
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        strokeColor: root.charging ? Colors.green
                                   : root.batCap > 40 ? Colors.accent2
                                   : root.batCap > 20 ? Colors.yellow
                                   : Colors.red
                        PathAngleArc {
                            centerX: 100; centerY: 100
                            radiusX: 82; radiusY: 82
                            startAngle: -230
                            sweepAngle: 280 * (root.batCap / 100)

                            Behavior on sweepAngle {
                                NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                // İç daire arka plan
                Rectangle {
                    anchors.centerIn: parent
                    width: 140; height: 140; radius: 70
                    color: Colors.pillBg
                }

                // Yüzde metni
                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Text {
                            text: root.charging ? "\uf0e7" : "\uf240"
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 18
                            color: root.charging ? Colors.green : Colors.accent2
                        }
                        Text {
                            text: root.batCap + "%"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            color: Colors.text
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.charging ? "CHARGING" : "NOT CHARGING"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        color: Colors.textHint
                    }
                }
            }

            // ── Güç Butonları ────────────────────
            GridLayout {
                columns: 4
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true

                Repeater {
                    model: [
                        { icon: "\uf023", label: "Lock",   cmd: ["hyprlock"] },
                        { icon: "\uf236", label: "Sleep",  cmd: ["systemctl", "suspend"] },
                        { icon: "\uf021", label: "Reboot", cmd: ["systemctl", "reboot"] },
                        { icon: "\uf011", label: "Power",  cmd: ["systemctl", "poweroff"] }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: 68
                        radius: 12
                        color: pwMA.containsMouse ? Colors.pillHover : Colors.pillBg
                        border.color: Colors.pillBorder; border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 20
                                color: Colors.text
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: 11
                                color: Colors.textMuted
                            }
                        }

                        MouseArea {
                            id: pwMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isOpen = false
                                pwProc.command = modelData.cmd
                                pwProc.running = true
                            }
                        }
                    }
                }
            }

            // ── Güç Profili ──────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 52
                radius: 14
                color: Colors.pillBg
                border.color: Colors.pillBorder; border.width: 1

                RowLayout {
                    anchors { fill: parent; margins: 6 }
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "Perform", icon: "\uf135", id: "performance" },
                            { label: "Balance", icon: "\uf24e", id: "balanced" },
                            { label: "Saver",   icon: "\uf06c", id: "power-saver" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            property bool active: root.powerProfile === modelData.id
                            property bool hovered: false

                            Layout.fillWidth: true
                            height: 40
                            radius: 10

                            color: active ? Colors.activeBg
                                : hovered ? Colors.pillHover
                                : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 13
                                    color: active ? Colors.accent : Colors.textMuted
                                }
                                Text {
                                    text: modelData.label
                                    font.pixelSize: 12
                                    font.weight: active ? Font.Medium : Font.Normal
                                    color: active ? Colors.accent : Colors.textMuted
                                }
                            }

                            MouseArea {
                                id: prMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                                onClicked: {
                                    root.powerProfile = modelData.id
                                    profileSetProc.command = ["powerprofilesctl", "set", modelData.id]
                                    profileSetProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }

        Process { id: pwProc; command: [] }
        Process { id: profileSetProc; command: [] }
    }
}
