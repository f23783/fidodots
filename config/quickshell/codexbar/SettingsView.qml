import QtQuick
import QtQuick.Layouts
import "."
import ".."

Item {
    id: root

    implicitHeight: 460
    implicitWidth: 340

    Flickable {
        id: settingsFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: settingsColumn
            width: settingsFlick.width
            spacing: 10

            Text {
                text: "Providers"
                color: Colors.textMuted
                font.pixelSize: 11
                font.weight: Font.Medium
                leftPadding: 4
            }

            Repeater {
                model: {
                    UsageService.revision
                    return UsageService.sortedProviders()
                }

                delegate: Rectangle {
                    id: providerRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 10
                    color: Colors.pillBg
                    border.color: Colors.pillBorder
                    border.width: 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8

                        Item {
                            implicitWidth: 18
                            implicitHeight: 18

                            Image {
                                id: settingsIcon
                                anchors.fill: parent
                                source: "icons/" + providerRow.modelData.id + ".svg"
                                sourceSize.width: 18
                                sourceSize.height: 18
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: settingsIcon.status === Image.Error
                                text: UsageService.displayName(providerRow.modelData.id).charAt(0)
                                color: Colors.textMuted
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: UsageService.displayName(providerRow.modelData.id)
                            color: providerRow.modelData.enabled === true
                                   ? Colors.text : Colors.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: providerToggle
                            property bool enabledValue: providerRow.modelData.enabled === true
                            implicitWidth: 38
                            implicitHeight: 22
                            radius: 11
                            color: enabledValue ? Colors.activeBg : Colors.pillBg
                            border.color: enabledValue ? Colors.activeBorder : Colors.pillBorder
                            border.width: 1

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                x: providerToggle.enabledValue ? parent.width - width - 3 : 3
                                color: providerToggle.enabledValue ? Colors.accent : Colors.textHint

                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: UsageService.setProviderEnabled(
                                    providerRow.modelData.id, !providerToggle.enabledValue)
                            }
                        }
                    }
                }
            }

            Text {
                Layout.topMargin: 8
                text: "Source per enabled provider"
                color: Colors.textMuted
                font.pixelSize: 11
                font.weight: Font.Medium
                leftPadding: 4
            }

            Repeater {
                model: {
                    UsageService.revision
                    return UsageService.enabledProviders.slice(0)
                }

                delegate: Rectangle {
                    id: sourceRow
                    required property string modelData

                    Layout.fillWidth: true
                    implicitHeight: sourceContents.implicitHeight + 16
                    radius: 10
                    color: Colors.pillBg
                    border.color: Colors.pillBorder
                    border.width: 1

                    ColumnLayout {
                        id: sourceContents
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: UsageService.displayName(sourceRow.modelData)
                                color: Colors.text
                                font.pixelSize: 12
                            }

                            RowLayout {
                                spacing: 4

                                Repeater {
                                    model: UsageService.hasApi(sourceRow.modelData)
                                           ? ["auto", "cli", "api"] : ["auto", "cli"]

                                    delegate: Rectangle {
                                        id: sourcePill
                                        required property string modelData
                                        property bool active: UsageService.sourceFor(sourceRow.modelData)
                                                              === modelData
                                        property bool hovered: false

                                        implicitWidth: sourceLabel.implicitWidth + 14
                                        implicitHeight: 26
                                        radius: 8
                                        color: active ? Colors.activeBg
                                               : hovered ? Colors.pillHover : "transparent"
                                        border.color: active ? Colors.activeBorder : Colors.pillBorder
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            id: sourceLabel
                                            anchors.centerIn: parent
                                            text: sourcePill.modelData.toUpperCase()
                                            color: sourcePill.active ? Colors.accent : Colors.textMuted
                                            font.pixelSize: 9
                                            font.weight: sourcePill.active ? Font.Medium : Font.Normal
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: sourcePill.hovered = true
                                            onExited: sourcePill.hovered = false
                                            onClicked: UsageService.setSource(sourceRow.modelData,
                                                                                sourcePill.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: UsageService.sourceNoteFor(sourceRow.modelData).length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                            text: UsageService.sourceNoteFor(sourceRow.modelData)
                            color: Colors.textHint
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Item { implicitHeight: 1 }
        }
    }
}
