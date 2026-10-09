import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    spacing: 8
    Layout.fillWidth: true

    property string songTitle: "Not Playing"
    property string songArtist: ""
    property real songProgress: 0
    property bool isPlaying: false

    Text {
        text: "Music"
        color: Colors.textMuted
        font.pixelSize: 11
        font.weight: Font.Medium
        leftPadding: 4
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: musicCol.implicitHeight + 24
        radius: 12
        color: Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, 0.04)
        border.color: Colors.pillBorder
        border.width: 1

        ColumnLayout {
            id: musicCol
            anchors { fill: parent; margins: 12 }
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: songTitle
                    color: Colors.text
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: songArtist
                    color: Colors.textHint
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            // İlerleme çubuğu
            Rectangle {
                Layout.fillWidth: true
                height: 3
                radius: 2
                color: Colors.pillBorder
                
                Rectangle {
                    width: parent.width * songProgress
                    height: 3
                    radius: 2
                    color: Colors.accent
                    Behavior on width { NumberAnimation { duration: 500 } }
                }
            }

            // Kontrol butonları
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                MusicButton {
                    icon: "\uf04a" // Geri ikonu
                    onClicked: {
                        playerctl.runCommand(["playerctl", "previous"]);
                        musicProc.running = true; // Durumu anında tazele
                    }
                }
                MusicButton {
                    icon: isPlaying ? "\uf04c" : "\uf04b" // Play/Pause ikonu
                    large: true
                    onClicked: {
                        // Optimistic UI: İkonu anında değiştirerek gecikme hissini yok ediyoruz
                        isPlaying = !isPlaying;
                        playerctl.runCommand(["playerctl", "play-pause"]);
                        musicProc.running = true; // İşlemi teyit etmek için güncellemeyi tetikle
                    }
                }
                MusicButton {
                    icon: "\uf04e" // İleri ikonu
                    onClicked: {
                        playerctl.runCommand(["playerctl", "next"]);
                        musicProc.running = true; // Durumu anında tazele
                    }
                }
            }
        }
    }

    // Polling (Veri Çekme) İşlemi: playerctl metadata
    Process {
        id: musicProc
        command: ["bash", "-c", "playerctl metadata --format '{{status}}|{{title}}|{{artist}}|{{position}}|{{mpris:length}}' 2>/dev/null || echo 'Stopped|||0|1'"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                var status = parts[0] || "Stopped";
                
                isPlaying = (status === "Playing");
                songTitle = parts[1] || "Not Playing";
                songArtist = parts[2] || "";
                
                var pos = parseFloat(parts[3]) || 0;
                var len = parseFloat(parts[4]) || 1;
                
                if (len <= 0) len = 1;
                songProgress = Math.min(pos / len, 1.0);
            }
        }
    }

    // Tıklama komutları için Process yönetimi
    Process {
        id: playerctl
        
        function runCommand(cmdArray) {
            if (running) {
                terminate(); // Önceki komut askıda kaldıysa sonlandır
            }
            command = cmdArray;
            running = true;
        }
    }

    // Arka plan güncelleyicisi
    Timer {
        id: musicTimer
        interval: Config.musicInterval // Config dosyanızdan gelen süre
        running: true
        repeat: true
        triggeredOnStart: true
        onIntervalChanged: { restart() }
        
        onTriggered: {
            if (!musicProc.running) {
                musicProc.running = true;
            }
        }
    }
}
