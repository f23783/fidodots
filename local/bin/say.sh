#!/usr/bin/env bash
# ─────────────────────────────────────────────
# Masaüstü için genel seslendirme katmanı.
#   say.sh "Headset battery, 91 percent"
#
# Motor sırası:
#   1. piper-tts (nöral, CPU) — varsa
#   2. espeak-ng               — yedek
#
# Üretilen ses metnin hash'iyle önbelleğe alınır; aynı cümle
# ikinci kez anında çalar, piper hiç çalışmaz.
# ─────────────────────────────────────────────
set -uo pipefail

TEXT="${*:-}"
[ -z "$TEXT" ] && exit 0

PIPER_ROOT="$HOME/.local/share/piper-tts"
PIPER_BIN="$PIPER_ROOT/venv/bin/piper"
VOICE="$PIPER_ROOT/voices/en_US-amy-medium.onnx"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/say"

# Seslendirme yüksekliği (0.0 - 1.0). Sistem sesinden bağımsız, sadece bu katman.
# SAY_VOLUME ortam değişkeniyle çağrı başına geçersiz kılınabilir.
VOLUME="${SAY_VOLUME:-0.35}"

play() {
    if command -v pw-play >/dev/null 2>&1; then
        pw-play --volume="$VOLUME" "$1"
    elif command -v paplay >/dev/null 2>&1; then
        # paplay 0-65536 ölçeği kullanır
        paplay --volume="$(awk -v v="$VOLUME" 'BEGIN{printf "%d", v*65536}')" "$1"
    else
        return 1
    fi
}

if [ -x "$PIPER_BIN" ] && [ -f "$VOICE" ]; then
    mkdir -p "$CACHE"
    key="$(printf '%s' "$TEXT" | sha256sum | cut -c1-32)"
    wav="$CACHE/$key.wav"

    if [ ! -s "$wav" ]; then
        printf '%s\n' "$TEXT" | "$PIPER_BIN" -m "$VOICE" -f "$wav" >/dev/null 2>&1 || rm -f "$wav"
    fi

    if [ -s "$wav" ]; then
        play "$wav" && exit 0
    fi
fi

# Yedek motor
exec espeak-ng -v en-us -s 160 -a "$(awk -v v="$VOLUME" 'BEGIN{printf "%d", v*200}')" "$TEXT" >/dev/null 2>&1
