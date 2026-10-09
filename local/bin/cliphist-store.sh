#!/usr/bin/env bash
# ─────────────────────────────────────────────
# cliphist yakalama filtresi. wl-paste --watch bunu çağırır.
# İki iş yapar:
#   1. Şifre yöneticisi işaretli panoları geçmişe yazmaz.
#   2. MAX_BYTES üstündeki girdileri (büyük ekran görüntüleri) atar —
#      geçmiş RAM'de tutulduğu için boyut sınırı şart.
# ─────────────────────────────────────────────
set -uo pipefail

MAX_BYTES=$((3 * 1024 * 1024))   # 3 MB

RUNDIR="/run/user/$(id -u)/cliphist"
mkdir -p "$RUNDIR"

# Bu MIME tiplerinden biri varsa girdi ATLANIR.
IGNORED_TYPES=(
    "x-kde-passwordManagerHint"
    "application/x-secret"
)

types="$(wl-paste --list-types 2>/dev/null)"
for t in "${IGNORED_TYPES[@]}"; do
    if grep -qiF -- "$t" <<<"$types"; then
        cat >/dev/null      # içeriği yut, hiçbir yere yazma
        exit 0
    fi
done

# Boyut kontrolü için önce tampona al.
BUF="$(mktemp "$RUNDIR/incoming.XXXXXX")"
trap 'rm -f "$BUF"' EXIT
cat > "$BUF"

size=$(stat -c '%s' "$BUF" 2>/dev/null || echo 0)
if [ "$size" -gt "$MAX_BYTES" ]; then
    exit 0
fi

cliphist store < "$BUF"
