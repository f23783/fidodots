#!/usr/bin/env bash
# say.sh önbelleğini kulaklık cümleleriyle önceden doldurur.
# Bir kez çalıştırılır; sonrasında her pil seviyesi anında konuşur.
set -uo pipefail
PIPER_ROOT="$HOME/.local/share/piper-tts"
PIPER_BIN="$PIPER_ROOT/venv/bin/piper"
VOICE="$PIPER_ROOT/voices/en_US-amy-medium.onnx"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/say"
mkdir -p "$CACHE"

gen() {
    local text="$1"
    local key wav
    key="$(printf '%s' "$text" | sha256sum | cut -c1-32)"
    wav="$CACHE/$key.wav"
    [ -s "$wav" ] && return 0
    printf '%s\n' "$text" | "$PIPER_BIN" -m "$VOICE" -f "$wav" >/dev/null 2>&1 || rm -f "$wav"
}

for i in $(seq 0 100); do
    gen "Headset battery, $i percent"
done
for i in $(seq 0 25); do
    gen "Headset battery low, $i percent"
done
gen "Headset not connected"
echo "önbellek hazır: $(ls -1 "$CACHE" | wc -l) dosya, $(du -sh "$CACHE" | cut -f1)"
