pragma Singleton
import QtQuick
import ".."

QtObject {
    readonly property color stale: Colors.textHint

    function color(pct): color {
        var value = Math.max(0, Math.min(100, Number(pct) || 0))
        var saturation = Math.max(0.45, Colors.accent.hslSaturation)
        var hue = 145 - value / 100 * 145
        return Qt.hsla(hue / 360, saturation, Colors.accent.hslLightness, 1)
    }
}
