#!/usr/bin/env bash
# Build a styled DMG for Contained with a per-channel background.
#
# Layout (matches the 400x528 backgrounds in Resources/dmg/):
#   - background image     : 400 x 528 pt  (the icon-view canvas)
#   - icon size            : 104 pt
#   - app icon center      : (200, 152)  -> centered, 100pt from the top
#   - Applications folder  : (200, 376)  -> centered, 100pt from the bottom
#
# NOTE: create-dmg's --window-size is the full window FRAME (Finder `bounds`),
# which includes the ~28pt title bar. The icon-view content height = frame - 28,
# and Finder draws the background top-anchored at natural size, so the frame
# must be 528 + 28 = 556 tall for the full image to show without clipping.
set -euo pipefail

CHANNEL="${1:?channel (stable|beta|nightly)}"
APP="${2:?path to .app}"
OUT="${3:?output dmg path}"
VOLNAME="${4:-Contained}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMGDIR="$ROOT/Resources/dmg"

# --- geometry ---
TITLEBAR=28
BG_W=400
BG_H=528
WIN_H=$((BG_H + TITLEBAR))   # 556

# Pick the channel background; fall back to stable if it's missing.
BG1="$DMGDIR/background-${CHANNEL}.png"
BG2="$DMGDIR/background-${CHANNEL}@2x.png"
if [ ! -f "$BG1" ]; then
  BG1="$DMGDIR/background-stable.png"
  BG2="$DMGDIR/background-stable@2x.png"
fi

# Fold 1x + 2x into a single HiDPI TIFF so Finder renders crisp on Retina.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BG="$WORK/background.tiff"
if [ -f "$BG2" ]; then
  tiffutil -cathidpicheck "$BG1" "$BG2" -out "$BG"
else
  cp "$BG1" "$BG"
fi

command -v create-dmg >/dev/null 2>&1 || { echo "create-dmg not found (brew install create-dmg)"; exit 1; }

APP_NAME="$(basename "$APP")"
rm -f "$OUT"
create-dmg \
  --volname "$VOLNAME" \
  --background "$BG" \
  --window-pos 200 120 \
  --window-size "$BG_W" "$WIN_H" \
  --icon-size 104 \
  --icon "$APP_NAME" 200 152 \
  --app-drop-link 200 376 \
  --hide-extension "$APP_NAME" \
  --no-internet-enable \
  "$OUT" \
  "$APP"
