#!/usr/bin/env bash
# ─────────────────────────────────────────────
# G733 düşük pil izleyicisi. Uyarı sıklığı pil düştükçe artar.
#
#   > %25   : sessiz, 10 dakikada bir yoklar
#   <= %25  : 20 dakikada bir uyarır
#   <= %15  : 10 dakikada bir uyarır  + sesli
#   <= %8   :  4 dakikada bir uyarır  + sesli
#   <= %4   :  2 dakikada bir uyarır  + sesli, kritik bildirim
#
# Kulaklık bağlı değilse hiç uyarmaz, seyrek yoklar.
# hyprland exec-once ile başlar.
# ─────────────────────────────────────────────
set -uo pipefail

SPEAK_BELOW=15          # bu seviyenin altında sesli de söyle
LAST_WARNED_AT=999      # aynı seviyede tekrar tekrar bağırmasın diye

while true; do
    LEVEL="$(headset-battery.sh --level 2>/dev/null)" || LEVEL=""

    if [ -z "$LEVEL" ]; then
        # kulaklık kapalı/bağlı değil — boşuna yoklamaya gerek yok
        LAST_WARNED_AT=999
        sleep 300
        continue
    fi

    if   [ "$LEVEL" -le 4 ];  then INTERVAL=120;  URGENCY=critical
    elif [ "$LEVEL" -le 8 ];  then INTERVAL=240;  URGENCY=critical
    elif [ "$LEVEL" -le 15 ]; then INTERVAL=600;  URGENCY=normal
    elif [ "$LEVEL" -le 25 ]; then INTERVAL=1200; URGENCY=normal
    else
        # güvenli bölge
        LAST_WARNED_AT=999
        sleep 600
        continue
    fi

    # Pil şarj olup yukarı çıktıysa sayacı sıfırla
    [ "$LEVEL" -gt "$LAST_WARNED_AT" ] && LAST_WARNED_AT=999

    notify-send -a "Kulaklık" -u "$URGENCY" -h "int:value:$LEVEL" \
        "🎧 G733 pili azalıyor" "%$LEVEL kaldı"

    if [ "$LEVEL" -le "$SPEAK_BELOW" ]; then
        ~/.local/bin/say.sh "Headset battery low, $LEVEL percent"
    fi

    LAST_WARNED_AT="$LEVEL"
    sleep "$INTERVAL"
done
