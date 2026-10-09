import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string deviceName: ""
    property string address: ""
    property string deviceIcon: ""
    property bool connected: false
    property bool paired: false
    property bool pairing: false
    property bool stateChanging: false
    property bool batteryAvailable: false
    property real battery: 0

    signal activated()
    signal forgetRequested()
    signal pairingCompleted()

    Layout.fillWidth: true
    implicitHeight: 52
    radius: 12
    color: connected ? Colors.activeBg
                     : (mouse.containsMouse ? Colors.pillHover : Colors.pillBg)
    border.color: connected ? Colors.activeBorder : Colors.pillBorder
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    onPairedChanged: if (paired) pairingCompleted()

    // BlueZ ikon adını Nerd Font simgesine dönüştür.
    function typeIcon(iconName) {
        var icon = (iconName || "").toLowerCase()
        if (icon.indexOf("mouse") >= 0) return "󰍽"
        if (icon.indexOf("keyboard") >= 0) return "󰌌"
        if (icon.indexOf("phone") >= 0 || icon.indexOf("cellular") >= 0) return "󰏲"
        if (icon.indexOf("speaker") >= 0) return "󰓃"
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0
                || icon.indexOf("audio") >= 0) return "󰋋"
        return "󰂯"
    }

    function batteryPercent() {
        var value = Number(root.battery)
        if (!isFinite(value)) return 0
        if (value >= 0 && value <= 1) value *= 100
        return Math.round(Math.max(0, Math.min(100, value)))
    }

    function statusText() {
        var bits = []
        if (root.connected) bits.push("bağlı")
        else if (root.paired) bits.push("eşleşmiş")
        else bits.push("bulundu")
        if (root.batteryAvailable) bits.push("pil %" + root.batteryPercent())
        return bits.join(" · ")
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(event) {
            if (event.button === Qt.RightButton) {
                if (root.paired) root.forgetRequested()
            } else {
                root.activated()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: root.typeIcon(root.deviceIcon)
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 18
            color: root.connected ? Colors.accent : Colors.textMuted
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: root.deviceName || root.address
                color: Colors.text
                font.pixelSize: 13
                font.weight: root.connected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.statusText()
                color: root.connected ? Colors.accent : Colors.textHint
                font.pixelSize: 10
            }
        }

        // Eşleştirme ve bağlantı geçişlerinde dönen durum göstergesi.
        Text {
            visible: root.pairing || root.stateChanging
            text: ""
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 13
            color: Colors.accent
            RotationAnimation on rotation {
                running: root.pairing || root.stateChanging
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }
    }
}
