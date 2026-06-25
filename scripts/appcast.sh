#!/usr/bin/env bash
# Generate / update the Sparkle appcast for built DMG(s) and stage it for GitHub Pages.
#
# One-time setup (keep the private key safe, never commit it):
#   generate_keys                       # from Sparkle's bin; prints the public EdDSA key for Info.plist
#
# Channels: a single appcast spans stable / beta / nightly. `generate_appcast` reads the channel from
# each DMG's embedded version metadata; mark pre-release DMGs by placing a channel file next to them
# (e.g. a `<name>.html` release-notes file is optional). Stable builds carry no channel tag.
#
# Usage:
#   ./scripts/appcast.sh <path-to-sparkle-bin-dir> [updates-dir]
#
# The appcast's download URLs point at the GitHub release assets via --download-url-prefix, so the
# DMGs live as release assets while appcast.xml is served from GitHub Pages (docs/appcast.xml).
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_BIN="${1:?Pass the path to Sparkle's bin directory (contains generate_appcast)}"
UPDATES_DIR="${2:-updates}"
# GitHub release asset base (the DMGs are uploaded as release assets). Override via env in CI.
DOWNLOAD_PREFIX="${DOWNLOAD_PREFIX:-https://github.com/tdeverx/contained-app/releases/download/}"

[ -d "$UPDATES_DIR" ] || { echo "✗ Updates dir '$UPDATES_DIR' not found"; exit 1; }

echo "▸ Generating appcast for $UPDATES_DIR (download prefix: $DOWNLOAD_PREFIX)…"
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "$DOWNLOAD_PREFIX" "$UPDATES_DIR"

# Serve from GitHub Pages: docs/ is the Pages source, so the feed resolves at
# https://<owner>.github.io/contained-app/appcast.xml
mkdir -p docs
cp "$UPDATES_DIR/appcast.xml" docs/appcast.xml
echo "✓ Wrote $UPDATES_DIR/appcast.xml and staged docs/appcast.xml."
echo "  Commit docs/appcast.xml and upload the DMG(s) as GitHub release assets."
