#!/usr/bin/env bash
set -e

PLUGIN_ID="dev.justin.gabotero.taskorbit"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Removing old installation..."
kpackagetool6 --type Plasma/Applet -r "$PLUGIN_ID" 2>/dev/null || true

echo "Clearing Plasma cache..."
rm -rf \
    "$HOME/.cache/plasmashell" \
    "$HOME/.cache/plasma.emojier" \
    "$HOME/.cache/krunner" \
    "$HOME/.cache/plasma_theme_"*.kcache 2>/dev/null || true

echo "Installing from $SCRIPT_DIR..."
kpackagetool6 --type Plasma/Applet -i "$SCRIPT_DIR"

echo "Done. Restart plasmashell to apply:"
echo "  kquitapp5 plasmashell && kstart5 plasmashell"
