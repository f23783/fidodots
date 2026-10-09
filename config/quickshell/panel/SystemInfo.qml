import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    spacing: 8
    Layout.fillWidth: true

    property real cpuVal: 0
    property real ramVal: 0
    property string ramText: ""
    property real diskVal: 0
    property string diskText: ""

    // CPU: /proc/stat oku — top'tan çok daha hafif
    property var lastIdle: 0
    property var lastTotal: 0

    Text {
        text: "System"
        color: Colors.textMuted
        font.pixelSize: 11
        font.weight: Font.Medium
        leftPadding: 4
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: infoCol.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
        border.color: Colors.pillBorder
        border.width: 1

        ColumnLayout {
            id: infoCol
            anchors { fill: parent; margins: 12 }
            spacing: 10

            StatBar { icon: "\uf4bc"; label: "CPU"; value: cpuVal }
            StatBar { icon: "\uefc5"; label: "RAM"; value: ramVal; valueText: ramText }
            StatBar { icon: "\udb80\udeca"; label: "Disk"; value: diskVal; valueText: diskText }
        }
    }

    // CPU timer
    Process {
        id: cpuProc
        command: ["bash", "-c", "head -1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/)
                var user = parseInt(parts[1])
                var nice = parseInt(parts[2])
                var system = parseInt(parts[3])
                var idle = parseInt(parts[4])
                var iowait = parseInt(parts[5])
                var irq = parseInt(parts[6])
                var softirq = parseInt(parts[7])

                var total = user + nice + system + idle + iowait + irq + softirq
                var diffIdle = idle - lastIdle
                var diffTotal = total - lastTotal

                if (diffTotal > 0)
                    cpuVal = Math.round((1 - diffIdle / diffTotal) * 100)

                lastIdle = idle
                lastTotal = total
            }
        }
    }

    // RAM timer
    Process {
        id: ramProc
        command: ["bash", "-c", "free -m | awk 'NR==2{print $2, $3}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                var total = parseFloat(parts[0])
                var used = parseFloat(parts[1])
                ramVal = Math.round((used / total) * 100)
                ramText = Math.round(used / 1024 * 10) / 10 + "G / " + Math.round(total / 1024 * 10) / 10 + "G"
            }
        }
    }

    // Disk timer
    Process {
        id: diskProc
        command: ["bash", "-c", "df -h / | awk 'NR==2{print $3, $2, $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(" ")
                diskVal = parseFloat(parts[2]) || 0
                diskText = parts[0] + " / " + parts[1]
            }
        }
    }

    Timer {
        id: sysTimer
        interval: Config.systemInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onIntervalChanged: { restart() }
        onTriggered: {
            cpuProc.running = true
            ramProc.running = true
            diskProc.running = true
        }
    }
}
