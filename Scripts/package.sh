#!/usr/bin/env bash
# Build, package, sign, notarize, and print release values for Contained.
# Usage: ./Scripts/package.sh <version|app|smoke|dmg|signed|notarized> [...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "✗ $*" >&2
  exit 1
}

required_resource_bundles=(
  "Contained_ContainedApp.bundle"
  "ContainedCore_ContainedCore.bundle"
  "SwiftTerm_SwiftTerm.bundle"
)

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./Scripts/package.sh version [base|build|sha|version|env] [stable|beta|nightly]
  ./Scripts/package.sh app [debug|release]
  ./Scripts/package.sh smoke [Contained.app]
  ./Scripts/package.sh dmg <stable|beta|nightly> <Contained.app> <output.dmg> [volume-name]
  ./Scripts/package.sh signed
  ./Scripts/package.sh notarized
USAGE
}

version_info() {
  local command="${1:-version}"
  local channel="${CHANNEL:-${2:-nightly}}"
  local base="${BASE_VERSION:-$(cat VERSION 2>/dev/null || echo 1.0.0)}"
  local build="${BUILD:-}"
  local sha="${SHA:-}"
  local build_source_ref="${BUILD_SOURCE_REF:-}"

  if [ -z "$sha" ]; then
    sha="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
  fi

  build_from_source_ref() {
    [ -n "$build_source_ref" ] || return 1
    local appcast
    appcast="$(git show "$build_source_ref:appcast.xml" 2>/dev/null || true)"
    [ -n "$appcast" ] || return 1

    SHORT_SHA="$sha" perl -0ne '
      my $sha = $ENV{"SHORT_SHA"};
      while (m{<item>.*?</item>}gs) {
        my $item = $&;
        next unless index($item, $sha) >= 0;
        if ($item =~ m{<sparkle:version>([^<]+)</sparkle:version>}) {
          print "$1\n";
          exit 0;
        }
      }
      exit 1;
    ' <<<"$appcast"
  }

  if [ -z "$build" ]; then
    build="$(build_from_source_ref || git rev-list --count HEAD 2>/dev/null || echo 1)"
  fi

  case "$build" in
    ''|*[!0-9]*)
      fail "Build number must be a positive integer, got '$build'"
      ;;
  esac

  case "$command" in
    base)
      printf '%s\n' "$base"
      ;;
    build)
      printf '%s\n' "$build"
      ;;
    sha)
      printf '%s\n' "$sha"
      ;;
    version)
      case "$channel" in
        stable)
          printf '%s\n' "$base"
          ;;
        beta)
          printf '%s-beta.%s+%s\n' "$base" "$build" "$sha"
          ;;
        nightly)
          printf '%s-nightly.%s+%s\n' "$base" "$build" "$sha"
          ;;
        *)
          fail "Unknown channel '$channel' (expected stable, beta, or nightly)"
          ;;
      esac
      ;;
    env)
      case "$channel" in
        stable|beta|nightly) ;;
        *) fail "Unknown channel '$channel' (expected stable, beta, or nightly)" ;;
      esac
      printf 'BASE_VERSION=%s\n' "$base"
      printf 'BUILD=%s\n' "$build"
      printf 'SHA=%s\n' "$sha"
      printf 'VERSION='
      CHANNEL="$channel" BUILD="$build" SHA="$sha" BASE_VERSION="$base" version_info version
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

sync_changelog_resource() {
  local source="CHANGELOG.md"
  local target="Sources/ContainedApp/Resources/CHANGELOG.md"
  [ -f "$source" ] || fail "$source not found"

  if cmp -s "$source" "$target"; then
    echo "✓ Bundled changelog is already in sync."
  else
    mkdir -p "$(dirname "$target")"
    cp "$source" "$target"
    echo "✓ Synced $source -> $target"
  fi
}

build_app() {
  local config="${1:-release}"
  local app="Contained.app"
  local current_release_notes="CurrentReleaseNotes.md"
  local channel="${CHANNEL:-nightly}"
  local version="${VERSION:-$(CHANNEL="$channel" version_info version)}"
  local build="${BUILD:-$(version_info build)}"

  sync_changelog_resource

  echo "▸ Building ($config)..."
  swift build -c "$config"

  local bin_path
  bin_path="$(swift build -c "$config" --show-bin-path)/Contained"
  [ -x "$bin_path" ] || fail "Built binary not found at $bin_path"

  echo "▸ Assembling ${app}..."
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin_path" "$app/Contents/MacOS/Contained"

  local icon_src="Resources/${channel}.icon"
  if [ -d "$icon_src" ]; then
    echo "▸ Compiling icon ($channel)..."
    local tmpicon
    tmpicon="$(mktemp -d)"
    cp -R "$icon_src" "$tmpicon/Contained.icon"
    xcrun actool "$tmpicon/Contained.icon" \
      --compile "$app/Contents/Resources" \
      --app-icon Contained \
      --output-partial-info-plist "$tmpicon/icon.plist" \
      --platform macosx --minimum-deployment-target 26 \
      --errors --warnings >/dev/null
    rm -rf "$tmpicon"
  else
    echo "⚠ No icon source at $icon_src - bundling without an app icon."
  fi

  local build_products
  build_products="$(swift build -c "$config" --show-bin-path)"
  local framework_src="$build_products/Sparkle.framework"
  if [ -d "$framework_src" ]; then
    mkdir -p "$app/Contents/Frameworks"
    cp -R "$framework_src" "$app/Contents/Frameworks/"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Contained" 2>/dev/null || true
  fi

  for bundle_name in "${required_resource_bundles[@]}"; do
    local bundle_res="$build_products/$bundle_name"
    [ -d "$bundle_res" ] || fail "Required SwiftPM resource bundle '$bundle_name' was not built"
    cp -R "$bundle_res" "$app/Contents/Resources/"
  done

  echo "▸ Generating bundled release notes..."
  CHANNEL="$channel" VERSION_VALUE="$version" ./Scripts/notes.sh body > "$app/Contents/Resources/$current_release_notes"

  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Contained</string>
  <key>CFBundleDisplayName</key><string>Contained</string>
  <key>CFBundleIdentifier</key><string>com.contained.app</string>
  <key>CFBundleExecutable</key><string>Contained</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$build</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>Contained</string>
  <key>CFBundleIconName</key><string>Contained</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Contained. All rights reserved.</string>
  <key>SUFeedURL</key><string>https://raw.githubusercontent.com/tdeverx/contained-app/nightly/appcast.xml</string>
  <key>SUPublicEDKey</key><string>M/wt6mIO/OCxhM5wK8Le0jCtaCBIhlRh2aBWv0jkq8o=</string>
  <key>SUEnableInstallerLauncherService</key><true/>
</dict>
</plist>
PLIST

  codesign --force --deep --sign - "$app" >/dev/null 2>&1 || true

  echo "✓ Built $app ($version build $build)"
  echo "  Run with: open $app"
}

smoke_bundle() {
  local app="${1:-Contained.app}"
  local plist="$app/Contents/Info.plist"
  local binary="$app/Contents/MacOS/Contained"
  local sparkle_framework="$app/Contents/Frameworks/Sparkle.framework"
  local current_release_notes="$app/Contents/Resources/CurrentReleaseNotes.md"

  [ -d "$app" ] || fail "App bundle '$app' was not found"
  [ -f "$plist" ] || fail "Info.plist is missing"
  [ -x "$binary" ] || fail "Executable '$binary' is missing or not executable"

  for bundle_name in "${required_resource_bundles[@]}"; do
    [ -d "$app/Contents/Resources/$bundle_name" ] \
      || fail "Required SwiftPM resource bundle '$bundle_name' is missing"
  done

  local resource_changelog="$app/Contents/Resources/Contained_ContainedApp.bundle/CHANGELOG.md"
  [ -f "$resource_changelog" ] || fail "Bundled CHANGELOG.md resource is missing"
  [ -s "$current_release_notes" ] || fail "CurrentReleaseNotes.md resource is missing or empty"
  [ -d "$sparkle_framework" ] || fail "Sparkle.framework is missing from the bundle"

  plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$plist"
  }

  local short_version
  local build_number
  short_version="$(plist_value CFBundleShortVersionString)"
  build_number="$(plist_value CFBundleVersion)"

  if [ -n "${VERSION:-}" ] && [ "$short_version" != "$VERSION" ]; then
    fail "CFBundleShortVersionString '$short_version' does not match VERSION '$VERSION'"
  fi

  case "$build_number" in
    ''|*[!0-9]*)
      fail "CFBundleVersion must be a numeric build number, got '$build_number'"
      ;;
  esac

  if [ -n "${BUILD:-}" ] && [ "$build_number" != "$BUILD" ]; then
    fail "CFBundleVersion '$build_number' does not match BUILD '$BUILD'"
  fi

  codesign --verify --deep --strict "$app" >/dev/null 2>&1 || fail "codesign verification failed for '$app'"

  echo "✓ Bundle validation passed for $app ($short_version build $build_number)."
}

make_dmg() {
  local channel="${1:?channel (stable|beta|nightly)}"
  local app="${2:?path to .app}"
  local out="${3:?output dmg path}"
  local volname="${4:-Contained}"
  local dmgdir="$ROOT/Resources/dmg"

  local titlebar=28
  local bg_w=400
  local bg_h=528
  local win_h=$((bg_h + titlebar))

  local bg1="$dmgdir/background-${channel}.png"
  local bg2="$dmgdir/background-${channel}@2x.png"
  if [ ! -f "$bg1" ]; then
    bg1="$dmgdir/background-stable.png"
    bg2="$dmgdir/background-stable@2x.png"
  fi

  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  local bg="$work/background.tiff"
  if [ -f "$bg2" ]; then
    tiffutil -cathidpicheck "$bg1" "$bg2" -out "$bg"
  else
    cp "$bg1" "$bg"
  fi

  command -v create-dmg >/dev/null 2>&1 || fail "create-dmg not found (brew install create-dmg)"

  local app_name
  app_name="$(basename "$app")"
  rm -f "$out"
  create-dmg \
    --volname "$volname" \
    --background "$bg" \
    --window-pos 200 120 \
    --window-size "$bg_w" "$win_h" \
    --icon-size 104 \
    --icon "$app_name" 200 152 \
    --app-drop-link 200 376 \
    --hide-extension "$app_name" \
    --no-internet-enable \
    "$out" \
    "$app"
}

distribution_package() {
  local notarize="$1"
  : "${DEV_ID:?Set DEV_ID to your Developer ID Application identity}"
  if [ "$notarize" = "true" ]; then
    : "${KEYCHAIN_PROFILE:?Set KEYCHAIN_PROFILE to your notarytool keychain profile}"
  fi

  local app="Contained.app"
  local dmg="Contained.dmg"
  local entitlements="Scripts/Contained.entitlements"
  local channel="${CHANNEL:-stable}"

  echo "▸ Building release bundle..."
  CHANNEL="$channel" build_app release

  echo "▸ Code-signing (hardened runtime)..."
  codesign --force --deep --options runtime --timestamp \
    --entitlements "$entitlements" --sign "$DEV_ID" "$app"
  codesign --verify --strict --verbose=2 "$app"

  echo "▸ Building DMG..."
  rm -f "$dmg"
  hdiutil create -volname "Contained" -srcfolder "$app" -ov -format UDZO "$dmg"

  echo "▸ Signing DMG..."
  codesign --force --timestamp --sign "$DEV_ID" "$dmg"

  if [ "$notarize" = "true" ]; then
    echo "▸ Notarizing (this can take a few minutes)..."
    xcrun notarytool submit "$dmg" --keychain-profile "$KEYCHAIN_PROFILE" --wait

    echo "▸ Stapling..."
    xcrun stapler staple "$dmg"
    xcrun stapler staple "$app"
    echo "✓ $dmg is signed, notarized, and stapled."
  else
    echo "✓ $dmg is signed."
  fi
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

case "$command" in
  version)
    version_info "$@"
    ;;
  app)
    build_app "${1:-release}"
    ;;
  smoke)
    smoke_bundle "$@"
    ;;
  dmg)
    make_dmg "$@"
    ;;
  signed)
    distribution_package false
    ;;
  notarized)
    distribution_package true
    ;;
  *)
    usage
    exit 2
    ;;
esac
