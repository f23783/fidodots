import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root
    property string icon: ""
    property real value: 50
    signal moved(real v)

    Layout.fillWidth: true
    spacing: 10

    Text {
        text: root.icon
        font.pixelSize: 16
        font.family: "JetBrainsMono Nerd Font Mono"
        color: Colors.textMuted
        Layout.preferredWidth: 20
        horizontalAlignment: Text.AlignHCenter
    }

    Item {
        id: sliderContainer
        Layout.fillWidth: true
        height: 20

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4; radius: 2
            color: Colors.pillBorder

            Rectangle {
                width: handle.x + handle.width / 2
                height: 4; radius: 2
                color: Colors.accent
            }
        }

        Rectangle {
            id: handle
            width: 14; height: 14; radius: 7
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(
                (root.value / 100) * (sliderContainer.width - width),
                sliderContainer.width - width
            ))
        }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onPressed: function(mouse) {
                var v = Math.max(0, Math.min(100, (mouse.x / sliderContainer.width) * 100))
                root.value = v; root.moved(v)
            }
            onPositionChanged: function(mouse) {
                if (pressed) {
                    var v = Math.max(0, Math.min(100, (mouse.x / sliderContainer.width) * 100))
                    root.value = v; root.moved(v)
                }
            }
        }
    }

    Text {
        text: Math.round(root.value) + "%"
        font.pixelSize: 11
        color: Colors.textHint
        Layout.preferredWidth: 32
        horizontalAlignment: Text.AlignRight
    }
}
