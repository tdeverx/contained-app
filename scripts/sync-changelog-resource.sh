#!/usr/bin/env bash
# Keep the app-bundled changelog resource in sync with the release changelog.
# Usage:
#   ./scripts/sync-changelog-resource.sh          # update the bundled resource
#   ./scripts/sync-changelog-resource.sh --check  # fail if the files differ
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="CHANGELOG.md"
TARGET="Sources/Contained/Resources/CHANGELOG.md"
MODE="${1:-sync}"

[ -f "$SOURCE" ] || { echo "✗ $SOURCE not found" >&2; exit 1; }
[ "$MODE" = "sync" ] || [ "$MODE" = "--check" ] || {
  echo "Usage: $0 [--check]" >&2
  exit 2
}

if cmp -s "$SOURCE" "$TARGET"; then
  echo "✓ Bundled changelog is already in sync."
elif [ "$MODE" = "--check" ]; then
  echo "✗ Bundled changelog is out of sync. Run ./scripts/sync-changelog-resource.sh and commit the result." >&2
  exit 1
else
  mkdir -p "$(dirname "$TARGET")"
  cp "$SOURCE" "$TARGET"
  echo "✓ Synced $SOURCE → $TARGET"
fi
