#!/usr/bin/env bash
# Fixture coverage for release/version/change/appcast helper scripts.
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "✗ $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  grep -Fq -- "$needle" <<< "$haystack" || fail "$label did not contain '$needle'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" <<< "$haystack"; then
    fail "$label unexpectedly contained '$needle'"
  fi
}

mkdir -p .release
tmp="$(mktemp -d .release/test-release-scripts.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

echo "▸ Checking version-info validation..."
if BUILD=abc ./scripts/version-info.sh build >/dev/null 2>&1; then
  fail "version-info accepted a non-numeric BUILD"
fi

env_output="$(CHANNEL=beta BUILD=123 SHA=abcdef0 BASE_VERSION=9.8.7 ./scripts/version-info.sh env)"
assert_contains "$env_output" "BASE_VERSION=9.8.7" "version-info env"
assert_contains "$env_output" "BUILD=123" "version-info env"
assert_contains "$env_output" "SHA=abcdef0" "version-info env"
assert_contains "$env_output" "VERSION=9.8.7-beta.123+abcdef0" "version-info env"

echo "▸ Checking release-note composition..."
fixture_changelog="$tmp/CHANGELOG.md"
cat > "$fixture_changelog" <<'MARKDOWN'
# Changelog

## [Unreleased] - Current Build

### Fixed

- Build-specific fix.

## [9.8.7] - Version Notes

### Added

- Version-wide feature.
MARKDOWN

stable_notes="$(CHANGELOG="$fixture_changelog" VERSION_VALUE=9.8.7 CHANNEL=stable ./scripts/release-body.sh)"
assert_contains "$stable_notes" "## Full Release Notes" "stable notes"
assert_contains "$stable_notes" "Version-wide feature." "stable notes"
assert_not_contains "$stable_notes" "Changes Since Last" "stable notes"

beta_notes="$(CHANGELOG="$fixture_changelog" VERSION_VALUE=9.8.7-beta.123+abcdef0 CHANNEL=beta ./scripts/release-body.sh)"
assert_contains "$beta_notes" "## Changes Since Last Beta" "beta notes"
assert_contains "$beta_notes" "Build-specific fix." "beta notes"
assert_contains "$beta_notes" "## Full Release Notes" "beta notes"
assert_contains "$beta_notes" "Version-wide feature." "beta notes"

nightly_notes="$(CHANGELOG="$fixture_changelog" VERSION_VALUE=9.8.7-nightly.123+abcdef0 CHANNEL=nightly ./scripts/release-body.sh)"
assert_contains "$nightly_notes" "## Changes Since Last Nightly" "nightly notes"
assert_contains "$nightly_notes" "Build-specific fix." "nightly notes"
assert_contains "$nightly_notes" "## Full Release Notes" "nightly notes"

echo "▸ Checking change-fragment collection..."
mkdir -p "$tmp/changes"
printf '%s\n' '- Second fragment.' > "$tmp/changes/20260701-b.md"
printf '%s\n' '- First fragment.' > "$tmp/changes/20260701-a.md"
fragment_output="$(./scripts/collect-changes.sh "$tmp/changes")"
assert_contains "$fragment_output" "- First fragment." "fragment collection"
assert_contains "$fragment_output" "- Second fragment." "fragment collection"

echo "▸ Checking automatic channel deltas..."
delta_appcast="$tmp/previous-nightly.xml"
cat > "$delta_appcast" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Contained</title>
    <item>
      <title>1.0.0-nightly.82+98e9cd2</title>
      <sparkle:version>82</sparkle:version>
      <sparkle:shortVersionString>1.0.0-nightly.82+98e9cd2</sparkle:shortVersionString>
      <description>Previous nightly notes.</description>
      <enclosure url="https://example.com/Contained.dmg" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
auto_notes="$(APPCAST="$delta_appcast" CHANNEL=nightly VERSION_VALUE=1.0.0-nightly.84+293b593 ./scripts/release-body.sh)"
assert_contains "$auto_notes" "## Changes Since Last Nightly" "automatic nightly notes"
assert_contains "$auto_notes" "CI strengthening pass" "automatic nightly notes"
assert_not_contains "$auto_notes" "Toolbar & Navigation Redesign" "automatic nightly notes"

echo "▸ Checking appcast promotion and validation..."
promoted="$tmp/promoted.xml"
beta_only="$tmp/beta.xml"
stable_only="$tmp/stable.xml"
nightly="$tmp/nightly.xml"
cat > "$promoted" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Contained</title>
    <item>
      <title>9.8.7-beta.123+abcdef0</title>
      <sparkle:version>123</sparkle:version>
      <sparkle:shortVersionString>9.8.7-beta.123+abcdef0</sparkle:shortVersionString>
      <description>Beta notes.</description>
      <enclosure url="https://example.com/Contained.dmg" length="1" type="application/octet-stream"/>
    </item>
    <item>
      <title>9.8.7-nightly.124+abcdef1</title>
      <sparkle:version>124</sparkle:version>
      <sparkle:shortVersionString>9.8.7-nightly.124+abcdef1</sparkle:shortVersionString>
      <description>Nightly notes.</description>
      <enclosure url="https://example.com/Contained-nightly.dmg" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
cat > "$beta_only" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Contained</title>
    <item>
      <title>9.8.7-beta.123+abcdef0</title>
      <sparkle:version>123</sparkle:version>
      <sparkle:shortVersionString>9.8.7-beta.123+abcdef0</sparkle:shortVersionString>
      <description>Beta notes.</description>
      <enclosure url="https://example.com/Contained.dmg" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
cat > "$stable_only" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Contained</title>
    <item>
      <title>9.8.7</title>
      <sparkle:version>123</sparkle:version>
      <sparkle:shortVersionString>9.8.7</sparkle:shortVersionString>
      <description>Stable notes.</description>
      <enclosure url="https://example.com/Contained.dmg" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML

CHANNEL=beta ./scripts/validate-appcast.sh "$beta_only" >/dev/null
CHANNEL=stable ./scripts/validate-appcast.sh "$stable_only" >/dev/null
./scripts/promote-appcast-to-nightly.sh --non-nightly-only "$promoted" "$nightly" >/dev/null
promoted_output="$(cat "$nightly")"
assert_contains "$promoted_output" "9.8.7-beta.123+abcdef0" "promoted appcast"
assert_not_contains "$promoted_output" "9.8.7-nightly.124+abcdef1" "promoted appcast"
CHANNEL=nightly ./scripts/validate-appcast.sh "$nightly" >/dev/null

echo "✓ Release script fixture tests passed."
