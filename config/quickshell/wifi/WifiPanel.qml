import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

PanelWindow {
    id: root

    readonly property string ctl: "/home/__USER__/.local/bin/wifi-ctl"

    property bool isOpen: false
    readonly property bool radio: Networking.wifiEnabled
    property string device: ""
    property var active: null
    property var networks: []
    property string busySsid: ""
    property string expandedSsid: ""
    property string errorText: ""
    property bool scanning: false
    property string pendingPassword: ""
    // Sifre delegate'te degil burada tutulur: ListView delegate'i geri
    // donusturdugunde yazilan metin kaybolmasin.
    property string draftPassword: ""

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
            expandedSsid = ""
            refresh()
            rescan()
        }
    }

    onRadioChanged: {
        if (!radio) {
            networks = []
            scanning = false
        } else {
            refresh()
            rescan()
        }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void   { root.isOpen = true }
        function close(): void  { root.isOpen = false }
    }

    HyprlandFocusGrab {
        windows: [ root ]
        active: root.isOpen
        onActiveChanged: if (!active && root.expandedSsid === "") root.isOpen = false
    }

    // ── Veri katmanı ──────────────────────────────────────
    Process {
        id: statusProc
        command: [root.ctl, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.device = d.device || ""
                    root.active = d.active
                } catch (e) { }
            }
        }
    }

    Process {
        id: listProc
        command: [root.ctl, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.networks = root.radio && d.ok ? d.networks : []
                    if (!d.ok && d.error) root.errorText = d.error
                } catch (e) { root.networks = [] }
            }
        }
    }

    Process {
        id: actionProc

        // Şifre argv'ye YAZILMAZ; süreç doğunca stdin'den verilir.
        onProcessIdChanged: {
            if (processId > 0 && root.pendingPassword.length > 0) {
                write(root.pendingPassword + "\n")
                root.pendingPassword = ""
                stdinEnabled = false
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                root.busySsid = ""
                try {
                    var d = JSON.parse(text)
                    if (!d.ok) {
                        root.errorText = d.error || "işlem başarısız"
                    } else {
                        root.errorText = ""
                        root.expandedSsid = ""
                        root.draftPassword = ""
                    }
                } catch (e) {
                    root.errorText = "beklenmeyen yanıt"
                }
                root.refresh()
            }
        }
    }

    Process {
        id: rescanProc
        command: [root.ctl, "rescan"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                root.refresh()
            }
        }
    }

    function refresh() {
        statusProc.running = true
        if (root.radio) listProc.running = true
        else root.networks = []
    }

    function rescan() {
        if (!root.radio) return
        root.scanning = true
        rescanProc.running = true
    }

    function run(args, ssid, password) {
        root.busySsid = ssid || ""
        root.errorText = ""
        root.pendingPassword = password || ""
        actionProc.stdinEnabled = root.pendingPassword.length > 0
        actionProc.command = args
        actionProc.running = true
    }

    // Panel açıkken periyodik tazeleme
    // Sifre girilirken liste yenilenmez; yenilense delegate yeniden yaratilir
    // ve yazilan sifre ucar.
    Timer {
        interval: 8000
        running: root.isOpen && root.expandedSsid === "" && root.busySsid === ""
        repeat: true
        onTriggered: root.refresh()
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
                    text: "󰤨"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 18
                    color: root.radio ? Colors.accent : Colors.textHint
                }
                Text {
                    text: "Wi-Fi"
                    color: Colors.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Yeniden tara
                Rectangle {
                    width: 30; height: 30; radius: 15
                    color: scanMouse.containsMouse ? Colors.pillHover : Colors.pillBg
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 14
                        color: root.scanning ? Colors.accent : Colors.textMuted
                        RotationAnimation on rotation {
                            running: root.scanning; loops: Animation.Infinite
                            from: 0; to: 360; duration: 1000
                        }
                    }
                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rescan()
                    }
                }

                // Radyo aç/kapa
                Rectangle {
                    width: 46; height: 26; radius: 13
                    color: root.radio ? Colors.activeBg : Colors.pillBg
                    border.color: root.radio ? Colors.activeBorder : Colors.pillBorder
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        y: 4
                        x: root.radio ? parent.width - width - 4 : 4
                        color: root.radio ? Colors.accent : Colors.textHint
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                // Kapat
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

            // ── Aktif bağlantı kartı ──
            Rectangle {
                Layout.fillWidth: true
                visible: root.active !== null
                implicitHeight: 62
                radius: 12
                color: Colors.activeBg
                border.color: Colors.activeBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "󰤨"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 20
                        color: Colors.accent
                    }
                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text {
                            text: root.active ? root.active.ssid : ""
                            color: Colors.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.active && root.active.ip ? root.active.ip : "bağlanıyor…"
                            color: Colors.textHint
                            font.pixelSize: 10
                        }
                    }
                    Rectangle {
                        width: 72; height: 28; radius: 9
                        color: dcMouse.containsMouse ? Colors.pillHover : Colors.pillBg
                        border.color: Colors.pillBorder
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Kes"
                            color: Colors.red
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: dcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run([root.ctl, "disconnect"], "", "")
                        }
                    }
                }
            }

            // ── Hata satırı ──
            Rectangle {
                Layout.fillWidth: true
                visible: root.errorText.length > 0
                implicitHeight: errText.implicitHeight + 16
                radius: 10
                color: Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.15)
                border.color: Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.4)
                border.width: 1
                Text {
                    id: errText
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

            // Liste ve kapalı durum aynı alanı doldurur; içerik kaymaz.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── Radyo kapalı uyarısı ──
                Text {
                    visible: !root.radio
                    anchors.fill: parent
                    text: "Wi-Fi kapalı. Ağları görmek için yukarıdaki anahtarı aç."
                    color: Colors.textHint
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // ── Ağ listesi ──
                ListView {
                    id: list
                    visible: root.radio
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: root.networks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: NetworkRow {
                        width: list.width
                        ssid: modelData.ssid
                        signalStrength: modelData.signal
                        security: modelData.security
                        isOpen: modelData.open
                        band: modelData.band
                        inuse: modelData.inuse
                        saved: modelData.saved
                        busy: root.busySsid === modelData.ssid
                        expanded: root.expandedSsid === modelData.ssid
                        passwordText: root.expandedSsid === modelData.ssid ? root.draftPassword : ""
                        onPasswordEdited: function(t) { root.draftPassword = t }

                        onActivated: {
                            if (modelData.inuse) return

                            // Kayıtlı ya da şifresiz → doğrudan bağlan
                            if (modelData.saved || modelData.open) {
                                root.run([root.ctl, "connect", modelData.ssid], modelData.ssid, "")
                                return
                            }

                            // Şifre alanı kapalıysa aç, açıksa girilen şifreyle bağlan
                            if (root.expandedSsid !== modelData.ssid) {
                                root.expandedSsid = modelData.ssid
                                root.draftPassword = ""
                                focusPassword()
                            } else if (root.draftPassword.length > 0) {
                                root.run([root.ctl, "connect", modelData.ssid],
                                         modelData.ssid, root.draftPassword)
                                root.draftPassword = ""
                            }
                        }

                        onForgetRequested: {
                            root.run([root.ctl, "forget", modelData.ssid], modelData.ssid, "")
                        }
                    }
                }
            }

            // ── Alt ipucu ──
            Text {
                Layout.fillWidth: true
                visible: root.radio
                text: "Kayıtlı ağa sağ tık → unut"
                color: Colors.textHint
                font.pixelSize: 9
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
