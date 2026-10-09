#!/usr/bin/env bash
# fidodots installer: Arch + Hyprland desktop in one command.
#
#   ./install.sh               packages + config
#   ./install.sh --no-packages config only
#   ./install.sh --dry-run     show what would happen, touch nothing
#
# Existing files are moved to ~/.fidodots-backup/<timestamp>/ before being replaced.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.fidodots-backup/$STAMP"
DO_PACKAGES=1
DRY=0

for arg in "$@"; do
    case "$arg" in
        --no-packages) DO_PACKAGES=0 ;;
        --dry-run)     DRY=1 ;;
        -h|--help)     sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
run()  { if [ "$DRY" = 1 ]; then echo "   [dry] $*"; else "$@"; fi; }
list() { grep -vE '^\s*(#|$)' "$1"; }

[ "$(id -u)" -ne 0 ] || { warn "run as your normal user, not root (sudo is used where needed)"; exit 1; }
command -v pacman >/dev/null || { warn "this installer targets Arch Linux (pacman not found)"; exit 1; }

# ── 1. Packages ────────────────────────────────────────────────
if [ "$DO_PACKAGES" = 1 ]; then
    say "installing repo packages"
    run sudo pacman -S --needed --noconfirm base-devel git $(list "$REPO/packages/pacman.txt")

    if ! command -v yay >/dev/null; then
        say "bootstrapping yay"
        tmp="$(mktemp -d)"
        run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && run makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "installing AUR packages"
    run yay -S --needed --noconfirm $(list "$REPO/packages/aur.txt")

    say "enabling services"
    run sudo systemctl enable --now NetworkManager bluetooth
fi

# ── 2. Config ──────────────────────────────────────────────────
say "copying config (backup: $BACKUP)"
list "$REPO/MANIFEST" | while read -r src dst; do
    target="$HOME/$dst"
    if [ -e "$target" ] || [ -L "$target" ]; then
        run mkdir -p "$(dirname "$BACKUP/$dst")"
        run mv "$target" "$BACKUP/$dst"
    fi
    run mkdir -p "$(dirname "$target")"
    run cp -a "$REPO/$src" "$target"
    echo "   $dst"
done

# The repo stores home paths as /home/__USER__/; point them at this machine.
if [ "$DRY" = 0 ]; then
    list "$REPO/MANIFEST" | while read -r _ dst; do
        grep -rlI '/home/__USER__/' "$HOME/$dst" 2>/dev/null || true
    done | while read -r f; do
        sed -i "s|/home/__USER__/|$HOME/|g" "$f"
    done
fi

run chmod +x "$HOME"/.local/bin/*.sh "$HOME/.local/bin/wifi-ctl" "$HOME/.local/bin/wallpaper-autopause.py" "$HOME/wallpaper.sh"
run mkdir -p "$HOME/wallpaper"

# ── 3. Done ────────────────────────────────────────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ "$DRY" = 0 ]; then
    hyprctl reload >/dev/null && say "hyprland reloaded"
fi

cat <<EOF

Done. Next:
  1. Put an image or .mp4 in ~/wallpaper/
  2. Log into Hyprland and press SUPER+W to pick it. The whole desktop recolors from it.
EOF
[ -d "$BACKUP" ] && echo "Your previous files are in $BACKUP"
exit 0
