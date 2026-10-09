import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "."
import ".."

PanelWindow {
    id: root

    property string selectedProvider: ""
    property bool settingsOpen: false
    property int clockRevision: 0
    property bool busy: {
        UsageService.revision
        return UsageService.anyFetching()
    }
    property var selectedState: {
        UsageService.revision
        return UsageService.stateFor(selectedProvider)
    }

    anchors.right: true
    anchors.top: true

    implicitWidth: 380
    implicitHeight: Math.min(640, popupFrame.implicitHeight + 16)

    margins {
        top: 56
        right: 16
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"
    visible: UsageService.popupOpen

    function ensureSelection() {
        var enabled = UsageService.enabledProviders
        if (enabled.indexOf(selectedProvider) < 0)
            selectedProvider = enabled.length > 0 ? enabled[0] : ""
    }

    function relativeTime(timestamp) {
        clockRevision
        if (!timestamp || timestamp <= 0)
            return "never"
        var seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000))
        if (seconds < 10)
            return "just now"
        if (seconds < 60)
            return seconds + "s ago"
        var minutes = Math.floor(seconds / 60)
        if (minutes < 60)
            return minutes + "m ago"
        var hours = Math.floor(minutes / 60)
        if (hours < 24)
            return hours + "h ago"
        return Math.floor(hours / 24) + "d ago"
    }

    Component.onCompleted: ensureSelection()

    Connections {
        target: UsageService
        function onRevisionChanged() { root.ensureSelection() }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: root.clockRevision++
    }

    HyprlandFocusGrab {
        windows: [root]
        active: UsageService.popupOpen
        onCleared: UsageService.popupOpen = false
    }

    Rectangle {
        id: popupFrame
        anchors {
            fill: parent
            leftMargin: 8
            topMargin: 8
            bottomMargin: 8
        }
        implicitHeight: popupColumn.implicitHeight + 40
        radius: 20
        color: Qt.rgba(Colors.base.r, Colors.base.g, Colors.base.b, 0.96)
        border.color: Colors.pillBorder
        border.width: 1
        clip: true
        focus: true
        Keys.onEscapePressed: UsageService.popupOpen = false

        ColumnLayout {
            id: popupColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 20
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: "AI Usage"
                    color: Colors.text
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 9
                    color: refreshArea.containsMouse ? Colors.pillHover : Colors.pillBg
                    border.color: Colors.pillBorder
                    border.width: 1
                    opacity: root.busy ? 0.6 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: Colors.textMuted
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14

                        RotationAnimation on rotation {
                            running: root.busy
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UsageService.refreshAll()
                    }
                }

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 9
                    color: root.settingsOpen ? Colors.activeBg
                           : settingsArea.containsMouse ? Colors.pillHover : Colors.pillBg
                    border.color: root.settingsOpen ? Colors.activeBorder : Colors.pillBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\uf013"
                        color: root.settingsOpen ? Colors.accent : Colors.textMuted
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.settingsOpen = !root.settingsOpen
                    }
                }

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 9
                    color: closeArea.containsMouse ? Colors.pillHover : Colors.pillBg
                    border.color: Colors.pillBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        color: Colors.textHint
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: UsageService.popupOpen = false
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                contentWidth: tabRow.implicitWidth
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: tabRow
                    spacing: 6

                    Repeater {
                        model: {
                            UsageService.revision
                            return UsageService.enabledProviders.slice(0)
                        }

                        delegate: ProviderTab {
                            required property string modelData
                            providerId: modelData
                            label: UsageService.displayName(modelData)
                            selected: root.selectedProvider === modelData
                            onClicked: {
                                root.selectedProvider = modelData
                                root.settingsOpen = false
                            }
                        }
                    }
                }
            }

            UsageSection {
                visible: !root.settingsOpen
                Layout.fillWidth: true
                providerId: root.selectedProvider
            }

            SettingsView {
                visible: root.settingsOpen
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7

                Text {
                    text: "updated " + root.relativeTime(root.selectedState
                          ? root.selectedState.lastSuccess : 0)
                    color: Colors.textHint
                    font.pixelSize: 10
                }

                Rectangle {
                    visible: root.selectedState && root.selectedState.stale
                    implicitWidth: cachedText.implicitWidth + 12
                    implicitHeight: 20
                    radius: 7
                    color: Colors.pillBg
                    border.color: Colors.pillBorder
                    border.width: 1

                    Text {
                        id: cachedText
                        anchors.centerIn: parent
                        text: "cached"
                        color: Severity.stale
                        font.pixelSize: 9
                    }
                }

                Text {
                    visible: root.selectedState && root.selectedState.error
                             && root.selectedState.error.permanent
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.selectedState && root.selectedState.error
                          ? root.selectedState.error.message : ""
                    color: Colors.red
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                Item {
                    visible: !(root.selectedState && root.selectedState.error
                               && root.selectedState.error.permanent)
                    Layout.fillWidth: true
                }
            }
        }
    }
}
