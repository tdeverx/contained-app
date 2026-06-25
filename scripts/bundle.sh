#!/usr/bin/env bash
# Build Contained and assemble a runnable Contained.app bundle.
#
# The .app is a build artifact (git-ignored) — this script regenerates it from source.
# Usage: ./scripts/bundle.sh [debug|release]   (default: release)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="Contained.app"
# Marketing version (CFBundleShortVersionString): semver, with a pre-release suffix for non-stable
# channels (e.g. 1.0.0, 1.0.0-beta.1, 1.0.0-nightly.137+abc1234). Override via env in CI.
VERSION="${VERSION:-1.0.0-beta.1}"
# Build number (CFBundleVersion): a monotonic integer Sparkle orders by. Commit count always
# increases; fall back to 1 outside a git checkout.
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/Contained"
[ -x "$BIN_PATH" ] || { echo "✗ Built binary not found at $BIN_PATH"; exit 1; }

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/Contained"

# App icon (generate with scripts/make-icon.sh if missing).
if [ -f "Resources/Contained.icns" ]; then
  cp "Resources/Contained.icns" "$APP/Contents/Resources/Contained.icns"
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
  <!-- Sparkle auto-update: replace with your hosted appcast URL + the EdDSA public key from
       Sparkle's generate_keys before distributing a signed build. -->
  <key>SUFeedURL</key><string>https://tdeverx.github.io/contained-app/appcast.xml</string>
  <key>SUPublicEDKey</key><string>REPLACE_WITH_YOUR_SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableInstallerLauncherService</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the (rpath-patched) bundle is runnable locally. release.sh re-signs with a
# Developer ID for distribution.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Built $APP ($VERSION build $BUILD)"
echo "  Run with: open $APP"
