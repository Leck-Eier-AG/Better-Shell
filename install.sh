#!/usr/bin/env bash
# install.sh — Install Better-Shell: copy sounds and add source line to rc file.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.better-shell"
SOUNDS_SRC="$SCRIPT_DIR/sounds"
SOUNDS_DST="$INSTALL_DIR/sounds"
SOURCE_LINE="source \"$SCRIPT_DIR/better-shell.sh\""

echo "=== Better-Shell Installer ==="
echo

# --- copy sounds ---
if [ -d "$SOUNDS_SRC" ] && [ -n "$(ls -A "$SOUNDS_SRC" 2>/dev/null)" ]; then
    mkdir -p "$SOUNDS_DST"
    cp -n "$SOUNDS_SRC"/* "$SOUNDS_DST/" 2>/dev/null || true
    echo "[+] Sounds copied to $SOUNDS_DST"
else
    mkdir -p "$SOUNDS_DST"
    echo "[!] No bundled sounds found. Add .mp3/.wav/.ogg files to $SOUNDS_DST"
fi

# --- detect shell rc file ---
RC_FILE=""
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    RC_FILE="$HOME/.bashrc"
fi

if [ -z "$RC_FILE" ]; then
    echo "[!] Could not detect shell. Manually add this to your rc file:"
    echo "    $SOURCE_LINE"
    exit 0
fi

# --- append source line if missing ---
if [ -f "$RC_FILE" ] && grep -qF "better-shell.sh" "$RC_FILE" 2>/dev/null; then
    echo "[=] Already sourced in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# Better-Shell: play a sound on command errors" >> "$RC_FILE"
    echo "$SOURCE_LINE" >> "$RC_FILE"
    echo "[+] Added source line to $RC_FILE"
fi

echo
echo "Done! Restart your shell or run:"
echo "    source $RC_FILE"
echo
echo "Add your own sounds (.mp3/.wav/.ogg) to: $SOUNDS_DST"
