import QtQuick
import QtQuick.Layouts
import "."
import ".."

ColumnLayout {
    id: root

    property string providerId: ""
    property var providerState: {
        UsageService.revision
        return UsageService.stateFor(providerId)
    }
    property var usageData: providerState && providerState.data ? providerState.data : null

    spacing: 14
    Layout.fillWidth: true

    function resetText(windowData) {
        if (windowData && typeof windowData.resetDescription === "string"
                && windowData.resetDescription.length > 0)
            return windowData.resetDescription
        if (!windowData || typeof windowData.resetsAt !== "string")
            return "unknown"
        var timestamp = Date.parse(windowData.resetsAt)
        if (isNaN(timestamp))
            return "unknown"
        var reset = new Date(timestamp)
        var now = new Date()
        if (reset.getFullYear() === now.getFullYear()
                && reset.getMonth() === now.getMonth()
                && reset.getDate() === now.getDate())
            return Qt.formatTime(reset, "h:mm AP")
        return Qt.formatDateTime(reset, "MMM d, h:mm AP")
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: UsageService.displayName(root.providerId)
            color: Colors.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: root.usageData && root.usageData.planLabel
            implicitWidth: planText.implicitWidth + 12
            implicitHeight: 22
            radius: 8
            color: Colors.pillBg
            border.color: Colors.pillBorder
            border.width: 1

            Text {
                id: planText
                anchors.centerIn: parent
                text: root.usageData && root.usageData.planLabel || ""
                color: Colors.textMuted
                font.pixelSize: 10
            }
        }

        Rectangle {
            visible: root.usageData !== null
            implicitWidth: sourceText.implicitWidth + 12
            implicitHeight: 22
            radius: 8
            color: Colors.activeBg
            border.color: Colors.activeBorder
            border.width: 1

            Text {
                id: sourceText
                anchors.centerIn: parent
                text: root.usageData && root.usageData.source === "api" ? "API" : "CLI"
                color: Colors.accent
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }

    Repeater {
        model: root.usageData && Array.isArray(root.usageData.windows)
                ? root.usageData.windows : []

        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: modelData.label || "Usage"
                    color: Colors.textMuted
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Math.round(Number(modelData.usedPercent) || 0) + "%"
                    color: Severity.color(modelData.usedPercent)
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                id: progressTrack
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Colors.pillBg
                clip: true

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(100,
                            Number(modelData.usedPercent) || 0)) / 100
                    radius: 4
                    color: Severity.color(modelData.usedPercent)

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "resets " + root.resetText(modelData)
                color: Colors.textMuted
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }

            Text {
                visible: typeof modelData.paceSummary === "string"
                         && modelData.paceSummary.length > 0
                Layout.fillWidth: true
                text: modelData.paceSummary || ""
                color: Colors.textHint
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
    }

    Text {
        visible: root.usageData && root.usageData.cost
        Layout.fillWidth: true
        property var cost: root.usageData && root.usageData.cost
        text: cost ? "$" + cost.used + " / $" + cost.limit + " · " + cost.period : ""
        color: Colors.textMuted
        font.pixelSize: 11
    }

    Text {
        visible: root.providerState && root.providerState.error
                 && root.providerState.error.permanent
        Layout.fillWidth: true
        text: root.providerState && root.providerState.error
              ? root.providerState.error.message : ""
        color: Colors.red
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }

    Text {
        visible: !root.usageData
        Layout.fillWidth: true
        Layout.preferredHeight: 100
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "No data — " + (root.providerState && root.providerState.error
              ? root.providerState.error.message : "waiting for first refresh")
        color: Colors.textHint
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }
}
