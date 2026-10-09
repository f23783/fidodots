import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string ssid: ""
    property int signalStrength: 0
    property string security: ""
    property bool isOpen: false
    property string band: ""
    property bool inuse: false
    property bool saved: false
    property bool expanded: false
    property bool busy: false
    property string passwordText: ""

    signal activated()
    signal passwordEdited(string text)
    signal forgetRequested()

    Layout.fillWidth: true
    implicitHeight: expanded ? 108 : 52
    radius: 12
    color: inuse ? Colors.activeBg
                 : (mouse.containsMouse ? Colors.pillHover : Colors.pillBg)
    border.color: inuse ? Colors.activeBorder : Colors.pillBorder
    border.width: 1
    clip: true

    Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }

    // Sinyal gücüne göre ikon
    function signalIcon(s) {
        if (s >= 75) return "󰤨"   // dört çubuk
        if (s >= 50) return "󰤥"   // üç
        if (s >= 25) return "󰤢"   // iki
        return "󰤟"                 // bir
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: root.expanded ? 56 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(e) {
            if (e.button === Qt.RightButton) {
                if (root.saved) root.forgetRequested()
            } else {
                root.activated()
            }
        }
    }

    RowLayout {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 52
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: root.signalIcon(root.signalStrength)
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 17
            color: root.inuse ? Colors.accent : Colors.textMuted
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            RowLayout {
                spacing: 6
                Text {
                    text: root.ssid
                    color: Colors.text
                    font.pixelSize: 13
                    font.weight: root.inuse ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    Layout.maximumWidth: 190
                }
                Text {
                    visible: !root.isOpen
                    text: "󰃼"          // kilit
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.pixelSize: 10
                    color: Colors.textHint
                }
            }

            Text {
                text: {
                    var bits = []
                    if (root.inuse) bits.push("bağlı")
                    else if (root.saved) bits.push("kayıtlı")
                    if (root.band) bits.push(root.band)
                    bits.push("%" + root.signalStrength)
                    return bits.join(" · ")
                }
                color: root.inuse ? Colors.accent : Colors.textHint
                font.pixelSize: 10
            }
        }

        // Meşgul göstergesi
        Text {
            visible: root.busy
            text: ""
            font.family: "JetBrainsMono Nerd Font Mono"
            font.pixelSize: 13
            color: Colors.accent
            RotationAnimation on rotation {
                running: root.busy; loops: Animation.Infinite
                from: 0; to: 360; duration: 900
            }
        }
    }

    // Şifre alanı — sadece genişletildiğinde
    RowLayout {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: 12
        anchors.bottomMargin: 10
        height: 36
        spacing: 8
        visible: root.expanded
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 9
            color: Colors.base
            border.color: pwField.activeFocus ? Colors.activeBorder : Colors.pillBorder
            border.width: 1

            TextInput {
                id: pwField
                objectName: "passwordField"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.text
                font.pixelSize: 12
                echoMode: TextInput.Password
                clip: true
                // Tek yonlu akis: alan -> panel. text'i her tus vurusunda
                // degisen bir ozellige BAGLAMIYORUZ; bagli olsaydi imlec
                // ziplayabilir ve karakter dusebilirdi.
                Component.onCompleted: text = root.passwordText
                onTextEdited: root.passwordEdited(text)
                onAccepted: root.activated()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Şifre"
                    color: Colors.textHint
                    font.pixelSize: 12
                    visible: pwField.text.length === 0 && !pwField.activeFocus
                }
            }
        }

        Rectangle {
            width: 74; height: 34; radius: 9
            color: connectMouse.containsMouse ? Colors.activeBorder : Colors.activeBg
            border.color: Colors.activeBorder
            border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }

            Text {
                anchors.centerIn: parent
                text: "Bağlan"
                color: Colors.text
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            MouseArea {
                id: connectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activated()
            }
        }
    }

    function password() { return pwField.text }
    function clearPassword() { pwField.text = "" }
    function focusPassword() { pwField.forceActiveFocus() }
}
