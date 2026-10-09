#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Pano geçmişi menüsü (rofi + cliphist)
#   SUPER+V           → menüyü aç
#   Enter             → seçileni panoya kopyala
#   Shift+Delete      → seçileni geçmişten sil
#   Ctrl+Shift+Delete → tüm geçmişi temizle
# Geçmiş RAM'de (/run/user/UID/cliphist/db) — reboot'ta yok olur.
# Renkler matugen'den: rofi/matugen-colors.rasi
# ─────────────────────────────────────────────
set -uo pipefail

# db dizini tmpfs'te; her oturumda yeniden oluşur.
mkdir -p "/run/user/$(id -u)/cliphist"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Pano" "$1"; }

for cmd in cliphist rofi wl-copy; do
    command -v "$cmd" >/dev/null 2>&1 || { notify "Eksik komut: $cmd"; exit 1; }
done

if [ -z "$(cliphist list 2>/dev/null)" ]; then
    notify "Geçmiş boş."
    exit 0
fi

SELECTED="$(
    cliphist list | rofi -dmenu \
        -p "Pano" \
        -i \
        -display-columns 2 \
        -kb-delete-entry "" \
        -kb-custom-1 "Shift+Delete" \
        -kb-custom-2 "Ctrl+Shift+Delete" \
        -theme-str 'window { width: 45%; }' \
        -theme-str 'listview { lines: 12; }'
)"
RC=$?

case "$RC" in
    0)  # Enter → panoya kopyala
        [ -z "$SELECTED" ] && exit 0
        printf '%s' "$SELECTED" | cliphist decode | wl-copy
        ;;
    10) # Shift+Delete → tek girdiyi sil
        [ -z "$SELECTED" ] && exit 0
        printf '%s' "$SELECTED" | cliphist delete
        notify "Girdi silindi."
        ;;
    11) # Ctrl+Shift+Delete → hepsini temizle
        cliphist wipe
        notify "Geçmiş temizlendi."
        ;;
    *)  # 1 = iptal
        exit 0
        ;;
esac
