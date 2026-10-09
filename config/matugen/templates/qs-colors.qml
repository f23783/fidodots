pragma Singleton
import QtQuick

QtObject {
    // Bu dosya matugen tarafından otomatik üretilir
    // Kaynak: ~/.config/matugen/templates/qs-colors.qml
    // Hedef: ~/.config/quickshell/bar/Colors.qml

    readonly property color base:       "{{colors.surface.default.hex}}"
    readonly property color surface:    "{{colors.surface_container.default.hex}}"
    readonly property color overlay:    "{{colors.surface_container_high.default.hex}}"
    readonly property color text:       "{{colors.on_surface.default.hex}}"
    readonly property color textMuted:  "{{colors.on_surface_variant.default.hex}}"
    readonly property color textHint:   "{{colors.outline.default.hex}}"
    readonly property color accent:     "{{colors.primary.default.hex}}"
    readonly property color accent2:    "{{colors.secondary.default.hex}}"
    readonly property color accent3:    "{{colors.tertiary.default.hex}}"
    readonly property color red:        "{{colors.error.default.hex}}"
    
    // Matugen'in standart paletinde sarı ve yeşil için özel isimler bulunmayabilir, 
    // ancak primary_fixed ve secondary_fixed tonları bu işlev için harikadır.
    readonly property color yellow:     "{{colors.primary_fixed_dim.default.hex}}"
    readonly property color green:      "{{colors.secondary_fixed.default.hex}}"

    // Pill arka planları - Statik değerler yerine QML'in renk hesaplama yeteneğini kullanıyoruz.
    // Bu sayede renk ne olursa olsun şeffaflık oranı korunur.
    readonly property color pillBg:     Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property color pillHover:  Qt.rgba(text.r, text.g, text.b, 0.12)
    readonly property color pillBorder: Qt.rgba(text.r, text.g, text.b, 0.09)
    readonly property color activeBg:   Qt.rgba(accent.r, accent.g, accent.b, 0.20)
    readonly property color activeBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.50)
}
