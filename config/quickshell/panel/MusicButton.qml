import QtQuick
import ".."

Rectangle {
    property string icon: "\uf04b"
    property bool large: false
    signal clicked()

    width: large ? 44 : 36; height: large ? 44 : 36
    radius: large ? 22 : 18
    color: ma.containsMouse ? Colors.activeBg
         : large ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.15)
         : Colors.pillBg
    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: parent.icon
        font.pixelSize: parent.large ? 18 : 14
        font.family: "JetBrainsMono Nerd Font Mono"
        color: parent.large ? Colors.accent : Colors.textMuted
    }

    MouseArea {
        id: ma; anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}
