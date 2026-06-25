#!/usr/bin/env bash
# Generate / update this branch's Sparkle appcast for the built DMG(s).
#
# One-time setup (keep the private key safe, never commit it):
#   generate_keys                       # from Sparkle's bin; prints the public EdDSA key for Info.plist
#
# Per-branch feeds: each git branch (nightly / beta / main) owns an independent appcast.xml at the
# repo root, served raw from GitHub. The app picks the feed per channel at runtime (UpdaterController),
# so there's no cross-branch merging — promoting a branch just carries its manifest along. Items carry
# no channel tag; build numbers are monotonic across branches so the newest build always wins.
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
"$SPARKLE_BIN/generate_appcast" "${KEY_ARGS[@]}" --download-url-prefix "$DOWNLOAD_PREFIX" "$UPDATES_DIR"

# This branch's feed lives at the repo root; CI commits it back to the same branch.
cp "$UPDATES_DIR/appcast.xml" appcast.xml
echo "✓ Wrote appcast.xml at the repo root for this branch."
echo "  Commit appcast.xml and upload the DMG(s) as GitHub release assets."
