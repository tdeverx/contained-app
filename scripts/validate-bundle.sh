#!/usr/bin/env bash
# Smoke-check a built Contained.app before packaging or publishing.
set -euo pipefail

app="${1:-Contained.app}"
plist="$app/Contents/Info.plist"
binary="$app/Contents/MacOS/Contained"
sparkle_framework="$app/Contents/Frameworks/Sparkle.framework"

fail() {
  echo "✗ $*" >&2
  exit 1
}

[ -d "$app" ] || fail "App bundle '$app' was not found"
[ -f "$plist" ] || fail "Info.plist is missing"
[ -x "$binary" ] || fail "Executable '$binary' is missing or not executable"
resource_changelog=""
for bundle_name in Contained_ContainedApp.bundle Contained_Contained.bundle; do
  candidate="$app/Contents/Resources/$bundle_name/CHANGELOG.md"
  if [ -f "$candidate" ]; then
    resource_changelog="$candidate"
    break
  fi
done
[ -n "$resource_changelog" ] || fail "Bundled CHANGELOG.md resource is missing"
[ -d "$sparkle_framework" ] || fail "Sparkle.framework is missing from the bundle"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$plist"
}

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
