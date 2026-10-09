#!/usr/bin/env bash
# Kullanım: ./wallpaper.sh /path/to/wallpaper.{jpg,jpeg,png,webp,mp4}
# Image wallpaper: awww
# Video wallpaper: mpvpaper
# Tema renkleri: matugen; video dosyalarında önce ffmpeg ile frame çıkarılır.

set -u

WALLPAPER="${1:-}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-matugen"

notify() {
    local title="$1"
    local message="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message"
    fi
    echo "$title: $message"
}

need_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify "Wallpaper" "Eksik komut: $cmd"
        return 1
    fi
}

usage() {
    echo "Kullanım: $0 /path/to/wallpaper.{jpg,jpeg,png,webp,mp4}"
}

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    usage
    exit 1
fi

EXT="${WALLPAPER##*.}"
EXT="${EXT,,}"

IS_IMAGE=0
IS_VIDEO=0

case "$EXT" in
    jpg|jpeg|png|webp)
        IS_IMAGE=1
        ;;
    mp4)
        IS_VIDEO=1
        ;;
    *)
        notify "Wallpaper" "Desteklenmeyen format: .$EXT"
        echo "Desteklenen formatlar: jpg, jpeg, png, webp, mp4"
        exit 1
        ;;
esac

MATUGEN_SOURCE="$WALLPAPER"

set_static_wallpaper() {
    need_cmd awww || exit 1

    # Video wallpaper açıksa kapat.
    pkill -x mpvpaper 2>/dev/null || true

    # awww daemon çalışmıyorsa başlat. Bazı sistemlerde hyprland autostart zaten yapıyor olabilir.
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        if command -v awww-daemon >/dev/null 2>&1; then
            nohup awww-daemon >/dev/null 2>&1 &
            sleep 0.25
        fi
    fi

    awww img "$WALLPAPER" \
        --transition-type wipe \
        --transition-angle 30 \
        --transition-duration 1.5
}

extract_video_frame_for_matugen() {
    need_cmd ffmpeg || exit 1

    mkdir -p "$CACHE_DIR"

    local safe_name
    safe_name="$(basename "$WALLPAPER")"
    local frame="$CACHE_DIR/${safe_name%.*}.matugen.png"

    # 1. saniyedeki kareyi al. Video çok kısaysa baştan kare almayı dene.
    if ! ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$WALLPAPER" -frames:v 1 "$frame"; then
        ffmpeg -hide_banner -loglevel error -y -i "$WALLPAPER" -frames:v 1 "$frame" || {
            notify "Wallpaper" "MP4'ten matugen için frame çıkarılamadı."
            exit 1
        }
    fi

    MATUGEN_SOURCE="$frame"
}

set_video_wallpaper() {
    need_cmd mpvpaper || exit 1
    need_cmd ffmpeg || exit 1

    # Static wallpaper daemon'ı kapat; aksi halde background layer'da mpvpaper ile çakışabilir.
    pkill -x awww-daemon 2>/dev/null || true
    pkill -x mpvpaper 2>/dev/null || true

    extract_video_frame_for_matugen

    # MONİTÖR BAŞINA AYRI SÜREÇ.
    # "ALL" ile tek süreç açılırsa, duvar kağıdı monitörlerden BİRİNDE bile görünür
    # olduğunda -p devreye girmez (boş bir workspace tüm tasarrufu iptal eder).
    # Her ekrana ayrı süreç açınca her biri kendi durumuna göre duraklar.
    # NOT: mpvpaper'in kendi -p/--auto-pause'u YALNIZCA tam ekran pencerede calisir
    # (man mpvpaper: "will still draw/render even if there is a normal window
    # blocking the wallpaper view entirely"). Tiling'de ise yaramaz. Bu yuzden
    # duraklatmayi ~/.local/bin/wallpaper-autopause.py Hyprland olaylarina gore yapar.
    local outputs
    outputs="$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys
try:
    print("\n".join(m["name"] for m in json.load(sys.stdin)))
except Exception:
    pass' 2>/dev/null)"

    if [ -z "$outputs" ]; then
        # hyprctl yoksa eski davranışa dön
        nohup mpvpaper -o "no-audio loop-file=inf hwdec=auto-safe" ALL "$WALLPAPER" >/dev/null 2>&1 &
        disown
        return
    fi

    while IFS= read -r out; do
        [ -z "$out" ] && continue
        # input-ipc-server: wallpaper-autopause.py bu soketten duraklatma komutu gönderir.
        nohup mpvpaper -o "no-audio loop-file=inf hwdec=auto-safe input-ipc-server=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mpvpaper-$out.sock" \
            "$out" "$WALLPAPER" >/dev/null 2>&1 &
        disown
    done <<< "$outputs"
    disown
}

run_matugen() {
    need_cmd matugen || return 1

    # matugen'in renk seçimi için beklemesini önlemek adına otomatik onay gönderiyoruz.
    echo "" | matugen image "$MATUGEN_SOURCE" --prefer saturation
}

reload_desktop_components() {
    if command -v waybar >/dev/null 2>&1; then
        pkill waybar 2>/dev/null || true
        nohup waybar >/dev/null 2>&1 &
        disown
    fi

    if command -v kitty >/dev/null 2>&1; then
        killall -SIGUSR1 kitty 2>/dev/null || true
    fi

    if command -v swaync-client >/dev/null 2>&1; then
        swaync-client -rs 2>/dev/null || true
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
}

if [ "$IS_IMAGE" -eq 1 ]; then
    set_static_wallpaper
elif [ "$IS_VIDEO" -eq 1 ]; then
    set_video_wallpaper
fi

run_matugen
reload_desktop_components

notify "Wallpaper" "Tema başarıyla güncellendi: $(basename "$WALLPAPER")"
