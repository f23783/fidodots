#!/usr/bin/env bash
# Pull the live config from $HOME back into this repo.
# Run after changing anything on the machine, then review `git diff` and commit.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

grep -vE '^\s*(#|$)' "$REPO/MANIFEST" | while read -r src dst; do
    live="$HOME/$dst"
    if [ ! -e "$live" ]; then
        echo "skip  $dst (not on this machine)"
        continue
    fi
    if [ -d "$live" ]; then
        mkdir -p "$REPO/$src"
        rsync -a --delete --exclude-from="$REPO/EXCLUDES" "$live/" "$REPO/$src/"
    else
        mkdir -p "$(dirname "$REPO/$src")"
        rsync -a "$live" "$REPO/$src"
    fi
    echo "sync  $dst"
done

# Paths are written portable in the repo; install.sh expands them again.
grep -rlI --exclude-dir=.git "$HOME/" "$REPO" | grep -v '/sync.sh$\|/install.sh$' | while read -r f; do
    sed -i "s|$HOME/|/home/__USER__/|g" "$f"
    echo "path  ${f#"$REPO"/}"
done || true

git -C "$REPO" status --short
