#!/usr/bin/env bash
# Generate / update this branch's Sparkle appcast for the built DMG(s).
#
# One-time setup (keep the private key safe, never commit it):
#   generate_keys                       # from Sparkle's bin; prints the public EdDSA key for Info.plist
#
# Per-branch feeds: stable and beta own their branch appcasts. Nightly is the superset feed: its
# workflow writes the newest nightly item, and beta/stable workflows merge their promoted item into
# nightly too. Items carry no channel tag; Sparkle orders by the retained CFBundleVersion build number.
#
# Usage:
#   ./scripts/appcast.sh <path-to-sparkle-bin-dir> [updates-dir]
# Env:
#   DOWNLOAD_PREFIX  GitHub release-asset base the enclosure URLs point at.
#   ED_KEY_FILE      Path to the EdDSA private key file (CI: written from SPARKLE_ED_PRIVATE_KEY).
set -euo pipefail
cd "$(dirname "$0")/.."

SPARKLE_BIN="${1:?Pass the path to the Sparkle bin directory containing generate_appcast}"
UPDATES_DIR="${2:-updates}"
# GitHub release asset base (the DMGs are uploaded as release assets). Override via env in CI.
DOWNLOAD_PREFIX="${DOWNLOAD_PREFIX:-https://github.com/tdeverx/contained-app/releases/download/}"

[ -d "$UPDATES_DIR" ] || { echo "✗ Updates dir '$UPDATES_DIR' not found"; exit 1; }

KEY_ARGS=()
[ -n "${ED_KEY_FILE:-}" ] && KEY_ARGS=(--ed-key-file "$ED_KEY_FILE")

echo "▸ Generating appcast for $UPDATES_DIR (download prefix: $DOWNLOAD_PREFIX)…"
./scripts/release-notes.sh "$UPDATES_DIR"
if [ "${#KEY_ARGS[@]}" -gt 0 ]; then
  "$SPARKLE_BIN/generate_appcast" "${KEY_ARGS[@]}" --embed-release-notes --download-url-prefix "$DOWNLOAD_PREFIX" "$UPDATES_DIR"
else
  "$SPARKLE_BIN/generate_appcast" --embed-release-notes --download-url-prefix "$DOWNLOAD_PREFIX" "$UPDATES_DIR"
fi

# This branch's feed lives at the repo root; CI commits it back to the same branch.
cp "$UPDATES_DIR/appcast.xml" appcast.xml
echo "✓ Wrote appcast.xml at the repo root for this branch."
echo "  Commit appcast.xml and upload the DMG(s) as GitHub release assets."
