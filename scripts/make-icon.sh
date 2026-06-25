#!/usr/bin/env bash
# Generate Contained.icns from the programmatic icon. Run once (or when the mark changes);
# the result is committed and copied into the bundle by bundle.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

PNG="$(mktemp -t contained-icon).png"
ICONSET="$(mktemp -d)/Contained.iconset"
mkdir -p "$ICONSET"

echo "▸ Rendering 1024px master…"
swift scripts/make-icon.swift "$PNG"

echo "▸ Building iconset…"
for size in 16 32 128 256 512; do
  sips -z $size $size "$PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) "$PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/Contained.icns
echo "✓ Wrote Resources/Contained.icns"
