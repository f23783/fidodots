import QtQuick
import QtQuick.Layouts
import "."
import ".."

Rectangle {
    id: root

    property string providerId: ""
    property string label: ""
    property bool selected: false
    property bool hovered: false

    signal clicked()

    implicitWidth: tabContent.implicitWidth + 20
    implicitHeight: 34
    radius: 10
    color: selected ? Colors.activeBg : hovered ? Colors.pillHover : Colors.pillBg
    border.color: selected ? Colors.activeBorder : Colors.pillBorder
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: tabContent
        anchors.centerIn: parent
        spacing: 6

        Item {
            implicitWidth: 16
            implicitHeight: 16

            Image {
                id: providerIcon
                anchors.fill: parent
                source: "icons/" + root.providerId + ".svg"
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.centerIn: parent
                visible: providerIcon.status === Image.Error
                text: root.label.length > 0 ? root.label.charAt(0).toUpperCase() : "?"
                color: root.selected ? Colors.accent : Colors.textMuted
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }

        Text {
            text: root.label
            color: root.selected ? Colors.accent : Colors.textMuted
            font.pixelSize: 12
            font.weight: root.selected ? Font.Medium : Font.Normal
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }
}
