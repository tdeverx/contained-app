#!/usr/bin/env bash
# Build, sign, notarize, and package Contained as a DMG for distribution.
#
# Requires YOUR credentials (run this yourself — Contained never handles them):
#   DEV_ID            "Developer ID Application: Your Name (TEAMID)"
#   KEYCHAIN_PROFILE  a notarytool keychain profile created once via:
#                       xcrun notarytool store-credentials "<profile>" \
#                         --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
# Usage: DEV_ID="Developer ID Application: …" KEYCHAIN_PROFILE=contained ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${DEV_ID:?Set DEV_ID to your Developer ID Application identity}"
: "${KEYCHAIN_PROFILE:?Set KEYCHAIN_PROFILE to your notarytool keychain profile}"

APP="Contained.app"
DMG="Contained.dmg"
ENTITLEMENTS="scripts/Contained.entitlements"

echo "▸ Building release bundle…"
./scripts/bundle.sh release

echo "▸ Code-signing (hardened runtime)…"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$DEV_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "▸ Building DMG…"
rm -f "$DMG"
hdiutil create -volname "Contained" -srcfolder "$APP" -ov -format UDZO "$DMG"

echo "▸ Signing DMG…"
codesign --force --timestamp --sign "$DEV_ID" "$DMG"

echo "▸ Notarizing (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait

echo "▸ Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "✓ $DMG is signed, notarized, and stapled — ready to distribute."
echo "  Verify with: spctl -a -t open --context context:primary-signature -v $DMG"
