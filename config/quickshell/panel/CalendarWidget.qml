import QtQuick
import QtQuick.Layouts
import ".."
ColumnLayout {
    spacing: 8
    Layout.fillWidth: true

    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var dayNames: ["M","T","W","T","F","S","S"]

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate()
    }

    function firstDayOfMonth(y, m) {
        var d = new Date(y, m, 1).getDay()
        return d === 0 ? 6 : d - 1  // Pazartesi = 0
    }

    Text {
        text: "Calendar"
        color: Colors.textMuted
        font.pixelSize: 11
        font.weight: Font.Medium
        leftPadding: 4
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: calCol.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
        border.color: Colors.pillBorder
        border.width: 1

        ColumnLayout {
            id: calCol
            anchors { fill: parent; margins: 12 }
            spacing: 6

            // Navigasyon
            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: prevMA.containsMouse ? Colors.pillHover : "transparent"
                    Text { anchors.centerIn: parent; text: ""; color: Colors.text; font.pixelSize: 12 }
                    MouseArea {
                        id: prevMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (calMonth === 0) { calMonth = 11; calYear-- }
                            else calMonth--
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: monthNames[calMonth] + " " + calYear
                    color: Colors.text; font.pixelSize: 13; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: nextMA.containsMouse ? Colors.pillHover : "transparent"
                    Text { anchors.centerIn: parent; text: ""; color: Colors.text; font.pixelSize: 12 }
                    MouseArea {
                        id: nextMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (calMonth === 11) { calMonth = 0; calYear++ }
                            else calMonth++
                        }
                    }
                }
            }

            // Gün başlıkları
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: dayNames
                    Text {
                        Layout.fillWidth: true
                        text: modelData; color: Colors.textHint
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Gün grid'i
            Grid {
                id: calendarGrid
                Layout.fillWidth: true
                columns: 7
                spacing: 2
                readonly property real cellWidth: (width - spacing * 6) / 7

                // Boş hücreler (ayın ilk gününe kadar)
                Repeater {
                    model: firstDayOfMonth(calYear, calMonth)
                    Item { width: calendarGrid.cellWidth; height: 28 }
                }

                // Günler
                Repeater {
                    model: daysInMonth(calYear, calMonth)

                    Rectangle {
                        width: calendarGrid.cellWidth; height: 28; radius: 8
                        property bool isToday: {
                            var t = new Date()
                            return (index + 1) === t.getDate() &&
                                   calMonth === t.getMonth() &&
                                   calYear === t.getFullYear()
                        }
                        color: isToday ? Colors.accent
                             : dayMA.containsMouse ? Colors.pillHover
                             : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            color: isToday ? Colors.base : Colors.text
                            font.pixelSize: 12
                            font.weight: isToday ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: dayMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
