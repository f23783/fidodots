import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property bool active: false
    property bool busy: false
    signal toggleRequested(bool desired)
    // Geriye dönük uyumluluk için korunur; yeni kod toggleRequested kullanır.
    signal toggled(bool on)

    Layout.fillWidth: true
    height: 52
    radius: 12

    color: active ? Colors.activeBg : Colors.pillBg
    border.color: active ? Colors.activeBorder : Colors.pillBorder
    border.width: 1
    opacity: !enabled ? 0.4 : busy ? 0.6 : 1.0

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Column {
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            font.pixelSize: 18
            font.family: "JetBrainsMono Nerd Font Mono"
            color: root.active ? Colors.accent : Colors.textHint
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: 11
            color: root.active ? Colors.text : Colors.textHint
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.busy
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggleRequested(!root.active)
    }
}
