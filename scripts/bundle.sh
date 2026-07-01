#!/usr/bin/env bash
# Build Contained and assemble a runnable Contained.app bundle.
#
# The .app is a build artifact (git-ignored) — this script regenerates it from source.
# Usage: ./scripts/bundle.sh [debug|release]   (default: release)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="Contained.app"
# Update channel — selects the per-channel app icon (Resources/<channel>.icon). Defaults to
# nightly (the default channel); CI overrides via env per branch.
CHANNEL="${CHANNEL:-nightly}"
# Marketing version (CFBundleShortVersionString): semver, with a pre-release suffix for non-stable
# channels (e.g. 1.0.0, 1.0.0-beta.1, 1.0.0-nightly.137+abc1234). Override via env in CI.
VERSION="${VERSION:-$(CHANNEL="$CHANNEL" ./scripts/version-info.sh version)}"
# Build number (CFBundleVersion): a monotonic integer Sparkle orders by. CI may set BUILD or
# BUILD_SOURCE_REF to retain the build number of a promoted nightly commit.
BUILD="${BUILD:-$(./scripts/version-info.sh build)}"

./scripts/sync-changelog-resource.sh

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/Contained"
[ -x "$BIN_PATH" ] || { echo "✗ Built binary not found at $BIN_PATH"; exit 1; }

echo "▸ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Contained"

# App icon: compile the per-channel Icon Composer source (Resources/<channel>.icon) with actool
# into Assets.car + Contained.icns. Renamed to Contained.icon first so the compiled icon name is
# uniform across channels (Info.plist's CFBundleIconName/File stay "Contained").
ICON_SRC="Resources/${CHANNEL}.icon"
if [ -d "$ICON_SRC" ]; then
  echo "▸ Compiling icon ($CHANNEL)…"
  TMPICON="$(mktemp -d)"
  cp -R "$ICON_SRC" "$TMPICON/Contained.icon"
  xcrun actool "$TMPICON/Contained.icon" \
    --compile "$APP/Contents/Resources" \
    --app-icon Contained \
    --output-partial-info-plist "$TMPICON/icon.plist" \
    --platform macosx --minimum-deployment-target 26 \
    --errors --warnings >/dev/null
  rm -rf "$TMPICON"
else
  echo "⚠ No icon source at $ICON_SRC — bundling without an app icon."
fi

# Embed Sparkle.framework (auto-update) and make the binary find it relocatably.
FRAMEWORK_SRC="$(swift build -c "$CONFIG" --show-bin-path)/Sparkle.framework"
if [ -d "$FRAMEWORK_SRC" ]; then
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$FRAMEWORK_SRC" "$APP/Contents/Frameworks/"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Contained" 2>/dev/null || true
fi

# Bundle the compiled String Catalog (Base localization) if SwiftPM produced one.
BUNDLE_RES="$(swift build -c "$CONFIG" --show-bin-path)/Contained_Contained.bundle"
if [ -d "$BUNDLE_RES" ]; then
  cp -R "$BUNDLE_RES" "$APP/Contents/Resources/" || true
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Contained</string>
  <key>CFBundleDisplayName</key><string>Contained</string>
  <key>CFBundleIdentifier</key><string>com.contained.app</string>
  <key>CFBundleExecutable</key><string>Contained</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>Contained</string>
  <key>CFBundleIconName</key><string>Contained</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Contained. All rights reserved.</string>
  <!-- Sparkle auto-update. SUPublicEDKey is the public half of the EdDSA keypair from
       generate_keys; the private half lives in the keychain (back it up, add as the
       SPARKLE_ED_PRIVATE_KEY CI secret). Each channel has its own feed at its git branch's repo
       root; the app overrides this per channel at runtime (see UpdaterController). Default points at
       nightly (the default channel) so an un-switched build still updates. -->
  <key>SUFeedURL</key><string>https://raw.githubusercontent.com/tdeverx/contained-app/nightly/appcast.xml</string>
  <key>SUPublicEDKey</key><string>M/wt6mIO/OCxhM5wK8Le0jCtaCBIhlRh2aBWv0jkq8o=</string>
  <key>SUEnableInstallerLauncherService</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the (rpath-patched) bundle is runnable locally. release.sh re-signs with a
# Developer ID for distribution.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Built $APP ($VERSION build $BUILD)"
echo "  Run with: open $APP"
