import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

PanelWindow {
    id: root

    property bool isOpen: false
    property string errorText: ""
    property string pendingConnectAddress: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter !== null && adapter.enabled

    anchors.right: true
    anchors.top: true

    implicitWidth: 360
    implicitHeight: 560

    margins { top: 56; right: 16 }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    color: "transparent"
    visible: isOpen

    onIsOpenChanged: {
        if (isOpen) {
            errorText = ""
            setDiscovering(true)
        } else {
            pendingConnectAddress = ""
            setDiscovering(false)
        }
    }

    onAdapterChanged: {
        if (root.isOpen && root.adapterEnabled) root.setDiscovering(true)
    }

    onAdapterEnabledChanged: {
        if (root.isOpen && root.adapterEnabled) root.setDiscovering(true)
        else if (!root.adapterEnabled) root.setDiscovering(false)
    }

    IpcHandler {
        target: "bluetooth"
        function toggle() { root.isOpen = !root.isOpen }
        function open()   { root.isOpen = true }
        function close()  { root.isOpen = false }
    }

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.isOpen
        onActiveChanged: if (!active) root.isOpen = false
    }

    // ── Yerel Bluetooth eylemleri ─────────────────────────
    function setDiscovering(enabled) {
        if (!root.adapter || !root.adapter.enabled) return
        try {
            root.adapter.discovering = enabled
        } catch (error) {
            root.errorText = "Tarama durumu değiştirilemedi: " + error
        }
    }

    function toggleAdapter() {
        if (!root.adapter) {
            root.errorText = "Bluetooth adaptörü bulunamadı"
            return
        }
        try {
            if (root.adapter.enabled && root.adapter.discovering)
                root.adapter.discovering = false
            root.adapter.enabled = !root.adapter.enabled
        } catch (error) {
            root.errorText = "Bluetooth durumu değiştirilemedi: " + error
        }
    }

    function stateChanging(device) {
        return device.state !== BluetoothDeviceState.Disconnected
                && device.state !== BluetoothDeviceState.Connected
    }

    function deviceName(device) {
        return device.name || device.deviceName || device.address
    }

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

    function batteryPercent(device) {
        var value = Number(device.battery)
        if (!isFinite(value)) return 0
        if (value >= 0 && value <= 1) value *= 100
        return Math.round(Math.max(0, Math.min(100, value)))
    }

    function connectDevice(device) {
        try {
            root.errorText = ""
            device.connect()
        } catch (error) {
            root.errorText = root.deviceName(device) + " bağlanamadı: " + error
        }
    }

    function disconnectDevice(device) {
        try {
            root.errorText = ""
            device.disconnect()
        } catch (error) {
            root.errorText = root.deviceName(device) + " bağlantısı kesilemedi: " + error
        }
    }

    function activateDevice(device) {
        if (device.pairing || root.stateChanging(device)) return
        if (device.paired) {
            if (device.connected) root.disconnectDevice(device)
            else root.connectDevice(device)
            return
        }

        try {
            root.errorText = ""
            root.pendingConnectAddress = device.address
            device.pair()
        } catch (error) {
            root.pendingConnectAddress = ""
            root.errorText = root.deviceName(device) + " eşleştirilemedi: " + error
        }
    }

    function finishPairing(device) {
        if (!device.paired || root.pendingConnectAddress !== device.address) return
        root.pendingConnectAddress = ""
        if (!device.connected) root.connectDevice(device)
    }

    function forgetDevice(device) {
        try {
            root.errorText = ""
            if (root.pendingConnectAddress === device.address)
                root.pendingConnectAddress = ""
            device.forget()
        } catch (error) {
            root.errorText = root.deviceName(device) + " unutulamadı: " + error
        }
    }

    // ── Görünüm ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        radius: 20
        color: Qt.rgba(Colors.base.r, Colors.base.g, Colors.base.b, 0.96)
        border.color: Colors.pillBorder
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Başlık ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂯"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 18
                    color: root.adapterEnabled ? Colors.accent : Colors.textHint
                }
                Text {
                    text: "Bluetooth"
                    color: Colors.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Cihaz taramasını aç/kapa.
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: scanMouse.containsMouse ? Colors.pillHover : Colors.pillBg
                    opacity: root.adapterEnabled ? 1 : 0.45
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14
                        color: root.adapter && root.adapter.discovering
                               ? Colors.accent : Colors.textMuted
                        RotationAnimation on rotation {
                            running: root.adapter !== null && root.adapter.discovering
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1000
                        }
                    }
                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        enabled: root.adapterEnabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setDiscovering(!root.adapter.discovering)
                    }
                }

                // Adaptör aç/kapa.
                Rectangle {
                    width: 46
                    height: 26
                    radius: 13
                    color: root.adapterEnabled ? Colors.activeBg : Colors.pillBg
                    border.color: root.adapterEnabled ? Colors.activeBorder : Colors.pillBorder
                    border.width: 1
                    opacity: root.adapter ? 1 : 0.45
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        y: 4
                        x: root.adapterEnabled ? parent.width - width - 4 : 4
                        color: root.adapterEnabled ? Colors.accent : Colors.textHint
                        Behavior on x {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.adapter !== null
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleAdapter()
                    }
                }

                // Kapat.
                Text {
                    text: "󰅖"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 15
                    color: Colors.textHint
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isOpen = false
                    }
                }
            }

            // ── Bağlı cihaz kartları ──
            Repeater {
                model: root.adapter ? root.adapter.devices : null

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    visible: modelData.connected
                    implicitHeight: visible ? 62 : 0
                    radius: 12
                    color: Colors.activeBg
                    border.color: Colors.activeBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: root.typeIcon(modelData.icon)
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 20
                            color: Colors.accent
                        }
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: root.deviceName(modelData)
                                color: Colors.text
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.batteryAvailable
                                      ? "bağlı · pil %" + root.batteryPercent(modelData)
                                      : "bağlı"
                                color: Colors.textHint
                                font.pixelSize: 10
                            }
                        }
                        Rectangle {
                            width: 72
                            height: 28
                            radius: 9
                            color: disconnectMouse.containsMouse
                                   ? Colors.pillHover : Colors.pillBg
                            border.color: Colors.pillBorder
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Kes"
                                color: Colors.red
                                font.pixelSize: 11
                            }
                            MouseArea {
                                id: disconnectMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.disconnectDevice(modelData)
                            }
                        }
                    }
                }
            }

            // ── Hata satırı ──
            Rectangle {
                Layout.fillWidth: true
                visible: root.errorText.length > 0
                implicitHeight: errorLabel.implicitHeight + 16
                radius: 10
                color: Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.15)
                border.color: Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.4)
                border.width: 1

                Text {
                    id: errorLabel
                    anchors.fill: parent
                    anchors.margins: 8
                    text: root.errorText
                    color: Colors.red
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.errorText = ""
                }
            }

            // Liste alanı adaptör kapalıyken de yüksekliğini korur.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: !root.adapterEnabled
                    text: root.adapter === null
                          ? "Bluetooth adaptörü bulunamadı"
                          : "Bluetooth kapalı"
                    color: Colors.textHint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Flickable {
                    id: deviceList
                    anchors.fill: parent
                    visible: root.adapterEnabled
                    clip: true
                    contentWidth: width
                    contentHeight: sections.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: sections
                        width: deviceList.width
                        spacing: 6

                        Text {
                            width: parent.width
                            text: "EŞLEŞMİŞ"
                            color: Colors.textHint
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            leftPadding: 4
                            bottomPadding: 2
                        }

                        Repeater {
                            model: root.adapter ? root.adapter.devices : null

                            delegate: DeviceRow {
                                required property var modelData

                                width: sections.width
                                visible: modelData.paired
                                height: visible ? implicitHeight : 0
                                deviceName: root.deviceName(modelData)
                                address: modelData.address
                                deviceIcon: modelData.icon
                                connected: modelData.connected
                                paired: modelData.paired
                                pairing: modelData.pairing
                                stateChanging: root.stateChanging(modelData)
                                batteryAvailable: modelData.batteryAvailable
                                battery: modelData.battery
                                onActivated: root.activateDevice(modelData)
                                onForgetRequested: root.forgetDevice(modelData)
                                onPairingCompleted: root.finishPairing(modelData)
                            }
                        }

                        Text {
                            width: parent.width
                            text: "BULUNAN"
                            color: Colors.textHint
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            leftPadding: 4
                            topPadding: 6
                            bottomPadding: 2
                        }

                        Repeater {
                            model: root.adapter ? root.adapter.devices : null

                            delegate: DeviceRow {
                                required property var modelData

                                width: sections.width
                                visible: !modelData.paired
                                height: visible ? implicitHeight : 0
                                deviceName: root.deviceName(modelData)
                                address: modelData.address
                                deviceIcon: modelData.icon
                                connected: modelData.connected
                                paired: modelData.paired
                                pairing: modelData.pairing
                                stateChanging: root.stateChanging(modelData)
                                batteryAvailable: modelData.batteryAvailable
                                battery: modelData.battery
                                onActivated: root.activateDevice(modelData)
                                onForgetRequested: root.forgetDevice(modelData)
                                onPairingCompleted: root.finishPairing(modelData)
                            }
                        }
                    }
                }
            }

            // ── Alt ipucu ──
            Text {
                Layout.fillWidth: true
                visible: root.adapterEnabled
                text: "Eşleşmiş cihaza sağ tık → unut"
                color: Colors.textHint
                font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
