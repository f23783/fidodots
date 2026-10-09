import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    property string icon: ""
    property string label: ""
    property real value: 0
    property string valueText: Math.round(value) + "%"

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: icon
        font.pixelSize: 14
        font.family: "JetBrainsMono Nerd Font Mono"
        color: Colors.textMuted
        Layout.preferredWidth: 18
        horizontalAlignment: Text.AlignHCenter
    }
    Text { text: label; font.pixelSize: 12; color: Colors.textHint; Layout.preferredWidth: 36 }

    Rectangle {
        Layout.fillWidth: true; height: 4; radius: 2
        color: Colors.pillBorder
        Rectangle {
            width: parent.width * (Math.min(value, 100) / 100)
            height: 4; radius: 2
            color: value > 80 ? Colors.red : value > 60 ? Colors.yellow : Colors.accent
            Behavior on width { NumberAnimation { duration: 400 } }
        }
    }

    Text { text: valueText; font.pixelSize: 11; color: Colors.textHint; Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight }
}
