#!/usr/bin/env bash
# ─────────────────────────────────────────────
# G733 pil durumu. headsetcontrol'ü sarar, tek yerden okunur.
#
#   headset-battery.sh            → bildirim göster (varsayılan)
#   headset-battery.sh --speak    → espeak-ng ile sesli söyle
#   headset-battery.sh --json     → ham json (waybar/quickshell için)
#   headset-battery.sh --waybar   → waybar custom modülü formatı
#   headset-battery.sh --level    → sadece yüzde sayısı (yoksa boş, çıkış 1)
# ─────────────────────────────────────────────
set -uo pipefail

MODE="${1:---notify}"

raw="$(headsetcontrol -o json 2>/dev/null)"

read -r STATUS LEVEL TTE <<<"$(
    printf '%s' "$raw" | python3 -c '
import json,sys
try:
    d = json.load(sys.stdin)
    dev = next(x for x in d["devices"] if "battery" in x)
    b = dev["battery"]
    print(b.get("status","UNKNOWN"), b.get("level",-1), b.get("time_to_empty_min",-1))
except Exception:
    print("NODEVICE -1 -1")
' 2>/dev/null || echo "NODEVICE -1 -1"
)"

# Bağlı ve okunabilir mi?
connected=0
[ "$STATUS" = "BATTERY_AVAILABLE" ] && [ "${LEVEL:--1}" -ge 0 ] && connected=1

# Kalan süreyi "13s 48dk" biçimine çevir
fmt_time() {
    local m="$1"
    [ "$m" -le 0 ] 2>/dev/null && { printf ''; return; }
    printf '%ds %ddk' "$((m / 60))" "$((m % 60))"
}

icon_for() {
    local l="$1"
    if   [ "$l" -ge 80 ]; then printf '󰋋'
    elif [ "$l" -ge 40 ]; then printf '󰋋'
    else                       printf '󰟎'
    fi
}

case "$MODE" in
    --level)
        [ "$connected" -eq 1 ] || exit 1
        printf '%s\n' "$LEVEL"
        ;;

    --json)
        printf '%s\n' "$raw"
        ;;

    --waybar)
        if [ "$connected" -eq 1 ]; then
            t="$(fmt_time "$TTE")"
            cls=ok; [ "$LEVEL" -le 20 ] && cls=warning; [ "$LEVEL" -le 10 ] && cls=critical
            printf '{"text":"%s %s%%","tooltip":"G733 · %%%s%s","class":"%s","percentage":%s}\n' \
                "$(icon_for "$LEVEL")" "$LEVEL" "$LEVEL" "${t:+ · ~$t kaldı}" "$cls" "$LEVEL"
        else
            printf '{"text":"","tooltip":"G733 bağlı değil","class":"disconnected"}\n'
        fi
        ;;

    --speak)
        if [ "$connected" -eq 1 ]; then
            ~/.local/bin/say.sh "Headset battery, $LEVEL percent"
        else
            ~/.local/bin/say.sh "Headset not connected"
        fi
        ;;

    --notify|*)
        if [ "$connected" -eq 1 ]; then
            t="$(fmt_time "$TTE")"
            notify-send -a "Kulaklık" -h "int:value:$LEVEL" \
                "🎧 G733 · %$LEVEL" "${t:+~$t kaldı}"
        else
            notify-send -a "Kulaklık" "🎧 G733" "Bağlı değil"
        fi
        ;;
esac
