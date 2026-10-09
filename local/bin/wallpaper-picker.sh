#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Rofi Wallpaper Picker
# Image dosyalarını ve MP4 video wallpaper'ları thumbnail ile gösterir.
# Seçilen wallpaper'ı wallpaper.sh'a gönderir.
# ─────────────────────────────────────────────

set -u

WALLPAPER_DIR="$HOME/wallpaper"
WALLPAPER_SCRIPT="$HOME/wallpaper.sh"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker-thumbnails"

notify() {
    local title="$1"
    local message="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message"
    fi
    echo "$title: $message"
}

# Klasör kontrolü
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify "Wallpaper Picker" "Klasör bulunamadı: $WALLPAPER_DIR"
    exit 1
fi

if [ ! -x "$WALLPAPER_SCRIPT" ]; then
    notify "Wallpaper Picker" "Script çalıştırılabilir değil veya bulunamadı: $WALLPAPER_SCRIPT"
    echo "Düzeltmek için: chmod +x $WALLPAPER_SCRIPT"
    exit 1
fi

mkdir -p "$THUMB_DIR"

is_video() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"
    [ "$ext" = "mp4" ]
}

thumbnail_for() {
    local file="$1"

    if is_video "$file"; then
        local stat_key hash thumb
        stat_key="$(stat -c '%n-%Y-%s' "$file" 2>/dev/null)"
        hash="$(printf '%s' "$stat_key" | sha1sum | awk '{print $1}')"
        thumb="$THUMB_DIR/$hash.png"

        if [ ! -f "$thumb" ]; then
            if command -v ffmpeg >/dev/null 2>&1; then
                ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$file" -frames:v 1 "$thumb" \
                    || ffmpeg -hide_banner -loglevel error -y -i "$file" -frames:v 1 "$thumb" \
                    || thumb="$file"
            else
                thumb="$file"
            fi
        fi

        printf '%s' "$thumb"
    else
        printf '%s' "$file"
    fi
}

# Wallpaper'ları rofi'ye thumbnail ile gönder
SELECTED=$(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.mp4" \) \
        -print | sort -f | \
    while IFS= read -r file; do
        name="$(basename "$file")"
        icon="$(thumbnail_for "$file")"
        printf '%s\0icon\x1f%s\n' "$name" "$icon"
    done | rofi -dmenu \
        -p "Wallpaper" \
        -show-icons \
        -theme-str 'listview { columns: 3; lines: 3; }' \
        -theme-str 'element { orientation: vertical; padding: 8px; }' \
        -theme-str 'element-icon { size: 180px; border-radius: 12px; }' \
        -theme-str 'element-text { horizontal-align: 0.5; }' \
        -theme-str 'window { width: 720px; }'
)

# İptal edildiyse çık
[ -z "${SELECTED:-}" ] && exit 0

# wallpaper.sh'ı çağır
"$WALLPAPER_SCRIPT" "$WALLPAPER_DIR/$SELECTED"
