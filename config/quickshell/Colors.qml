pragma Singleton
import QtQuick

QtObject {
    // Bu dosya matugen tarafından otomatik üretilir
    // Kaynak: ~/.config/matugen/templates/qs-colors.qml
    // Hedef: ~/.config/quickshell/bar/Colors.qml

    readonly property color base:       "#111318"
    readonly property color surface:    "#1e2025"
    readonly property color overlay:    "#282a2f"
    readonly property color text:       "#e2e2e9"
    readonly property color textMuted:  "#c4c6d0"
    readonly property color textHint:   "#8e9099"
    readonly property color accent:     "#abc7ff"
    readonly property color accent2:    "#bec6dc"
    readonly property color accent3:    "#ddbce0"
    readonly property color red:        "#ffb4ab"
    
    // Matugen'in standart paletinde sarı ve yeşil için özel isimler bulunmayabilir, 
    // ancak primary_fixed ve secondary_fixed tonları bu işlev için harikadır.
    readonly property color yellow:     "#abc7ff"
    readonly property color green:      "#dae2f9"

    // Pill arka planları - Statik değerler yerine QML'in renk hesaplama yeteneğini kullanıyoruz.
    // Bu sayede renk ne olursa olsun şeffaflık oranı korunur.
    readonly property color pillBg:     Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property color pillHover:  Qt.rgba(text.r, text.g, text.b, 0.12)
    readonly property color pillBorder: Qt.rgba(text.r, text.g, text.b, 0.09)
    readonly property color activeBg:   Qt.rgba(accent.r, accent.g, accent.b, 0.20)
    readonly property color activeBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.50)
}
