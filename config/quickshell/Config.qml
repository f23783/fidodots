pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int    barHeight:          52
    property int    barMarginTop:       8
    property int    barMarginLeft:      14
    property int    barMarginRight:     14
    property int    barRadius:          14
    property int    barSpacing:         6
    property int    workspaceCount:     8
    property bool   clockFormat24h:     false
    property int    clockInterval:      1000
    property int    weatherInterval:    1800000
    property int    networkInterval:    10000
    property int    batteryInterval:    30000
    property int    volumeInterval:     3000
    property int    volumeScrollStep:   2
    property int    panelWidth:         380
    property int    panelMarginTop:     56
    property int    panelMarginRight:   16
    property int    panelSpacing:       12
    property int    systemInterval:     3000
    property int    musicInterval:      3000
    property int    powerMenuWidth:     280
    property int    powerMenuMarginTop:     56
    property int    powerMenuMarginRight:   16

    property string cfgPath: ""

    // ── 1. Adım: config dosya yolunu bul ────────────────────
    property var _pathProc: Process {
        id: pathProc
        command: ["bash", "-c", "echo $HOME/.config/quickshell/qs-config.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.cfgPath = text.trim()
                console.log("[Config] CFG PATH:", root.cfgPath)
                loadProc.running = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: console.log("[Config] PATH ERROR:", text.trim())
        }
    }

    // ── 2. Adım: JSON oku ────────────────────────────────────
    property var _loadProc: Process {
        id: loadProc
        command: ["bash", "-c", "cat \"" + root.cfgPath + "\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim()
                console.log("[Config] RAW JSON:", raw.substring(0, 80))
                if (raw === "" || raw === "{}") {
                    console.log("[Config] No saved config, using defaults")
                    return
                }
                try {
                    var d = JSON.parse(raw)
                    var b = d.bar       || {}
                    var p = d.panel     || {}
                    var m = d.powerMenu || {}
                    console.log("[Config] Parsed bar keys:", Object.keys(b).join(", "))

                    if (b.barHeight         !== undefined) root.barHeight         = b.barHeight
                    if (b.barMarginTop      !== undefined) root.barMarginTop      = b.barMarginTop
                    if (b.barMarginLeft     !== undefined) root.barMarginLeft     = b.barMarginLeft
                    if (b.barMarginRight    !== undefined) root.barMarginRight    = b.barMarginRight
                    if (b.barRadius         !== undefined) root.barRadius         = b.barRadius
                    if (b.barSpacing        !== undefined) root.barSpacing        = b.barSpacing
                    if (b.workspaceCount    !== undefined) root.workspaceCount    = b.workspaceCount
                    if (b.clockFormat24h    !== undefined) root.clockFormat24h    = b.clockFormat24h
                    if (b.clockInterval     !== undefined) root.clockInterval     = b.clockInterval
                    if (b.weatherInterval   !== undefined) root.weatherInterval   = b.weatherInterval
                    if (b.networkInterval   !== undefined) root.networkInterval   = b.networkInterval
                    if (b.batteryInterval   !== undefined) root.batteryInterval   = b.batteryInterval
                    if (b.volumeInterval    !== undefined) root.volumeInterval    = b.volumeInterval
                    if (b.volumeScrollStep  !== undefined) root.volumeScrollStep  = b.volumeScrollStep
                    if (p.panelWidth        !== undefined) root.panelWidth        = p.panelWidth
                    if (p.panelMarginTop    !== undefined) root.panelMarginTop    = p.panelMarginTop
                    if (p.panelMarginRight  !== undefined) root.panelMarginRight  = p.panelMarginRight
                    if (p.panelSpacing      !== undefined) root.panelSpacing      = p.panelSpacing
                    if (p.systemInterval    !== undefined) root.systemInterval    = p.systemInterval
                    if (p.musicInterval     !== undefined) root.musicInterval     = p.musicInterval
                    if (m.powerMenuWidth        !== undefined) root.powerMenuWidth        = m.powerMenuWidth
                    if (m.powerMenuMarginTop    !== undefined) root.powerMenuMarginTop    = m.powerMenuMarginTop
                    if (m.powerMenuMarginRight  !== undefined) root.powerMenuMarginRight  = m.powerMenuMarginRight

                    console.log("[Config] Load OK — barHeight:", root.barHeight)
                } catch(e) {
                    console.log("[Config] PARSE ERROR:", e.toString())
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: console.log("[Config] LOAD STDERR:", text.trim())
        }
    }

    // ── 3. Adım: JSON yaz ────────────────────────────────────
    property var _writeProc: Process {
        id: writeProcStdin
        property string inputJson: ""
        property string outputPath: ""
        command: []
        stdout: StdioCollector {
            onStreamFinished: console.log("[Config] SAVE stdout:", text.trim())
        }
        stderr: StdioCollector {
            onStreamFinished: console.log("[Config] SAVE STDERR:", text.trim())
        }
        onRunningChanged: {
            if (!running && command.length > 0)
                console.log("[Config] Save done, exitCode:", exitCode)
        }
    }

    // ── 4. Adım: Quickshell yeniden başlat ──────────────────
    property var _restartProc: Process {
        id: restartProc
        command: []
        onRunningChanged: {
            if (!running && command.length > 0)
                console.log("[Config] Restart process finished")
        }
        stderr: StdioCollector {
            onStreamFinished: console.log("[Config] RESTART STDERR:", text.trim())
        }
    }

    function save() {
        if (cfgPath === "") {
            console.log("[Config] SAVE ABORTED: cfgPath empty")
            return
        }

        var obj = {
            bar: {
                barHeight: barHeight, barMarginTop: barMarginTop,
                barMarginLeft: barMarginLeft, barMarginRight: barMarginRight,
                barRadius: barRadius, barSpacing: barSpacing,
                workspaceCount: workspaceCount, clockFormat24h: clockFormat24h,
                clockInterval: clockInterval, weatherInterval: weatherInterval,
                networkInterval: networkInterval, batteryInterval: batteryInterval,
                volumeInterval: volumeInterval, volumeScrollStep: volumeScrollStep
            },
            panel: {
                panelWidth: panelWidth, panelMarginTop: panelMarginTop,
                panelMarginRight: panelMarginRight, panelSpacing: panelSpacing,
                systemInterval: systemInterval, musicInterval: musicInterval
            },
            powerMenu: {
                powerMenuWidth: powerMenuWidth, powerMenuMarginTop: powerMenuMarginTop,
                powerMenuMarginRight: powerMenuMarginRight
            }
        }

        var json = JSON.stringify(obj)
        console.log("[Config] Saving to:", cfgPath)
        console.log("[Config] JSON preview:", json.substring(0, 100))

        // Python ile yaz — en güvenilir yöntem
        writeProcStdin.command = ["bash", "-c", "printf '%s' " + JSON.stringify(json) + " > " + JSON.stringify(cfgPath)]
        writeProcStdin.running = true
    }

    function saveAndRestart() {
        console.log("[Config] saveAndRestart called")
        save()
        // Save bittikten 500ms sonra restart
        restartTimer.restart()
    }

    property var _restartTimer: Timer {
        id: restartTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("[Config] Restarting quickshell...")
            restartProc.command = ["bash", "-c", "pkill -x quickshell; sleep 0.3; nohup quickshell > /dev/null 2>&1 &"]
            restartProc.running = true
        }
    }
}
