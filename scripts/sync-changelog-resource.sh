#!/usr/bin/env bash
# Keep the app-bundled changelog resource in sync with the release changelog.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="CHANGELOG.md"
TARGET="Sources/Contained/Resources/CHANGELOG.md"

[ -f "$SOURCE" ] || { echo "✗ $SOURCE not found" >&2; exit 1; }
mkdir -p "$(dirname "$TARGET")"

if cmp -s "$SOURCE" "$TARGET"; then
  echo "✓ Bundled changelog is already in sync."
else
  cp "$SOURCE" "$TARGET"
  echo "✓ Synced $SOURCE → $TARGET"
fi
