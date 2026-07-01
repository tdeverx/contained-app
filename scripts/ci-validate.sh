#!/usr/bin/env bash
# Fast repository checks shared by PR and release workflows.
set -euo pipefail

cd "$(dirname "$0")/.."

base_ref=""
head_ref="HEAD"
require_release_note=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-ref)
      base_ref="${2:-}"
      [ -n "$base_ref" ] || { echo "✗ --base-ref requires a value" >&2; exit 1; }
      shift 2
      ;;
    --head-ref)
      head_ref="${2:-}"
      [ -n "$head_ref" ] || { echo "✗ --head-ref requires a value" >&2; exit 1; }
      shift 2
      ;;
    --require-release-note)
      require_release_note=true
      shift
      ;;
    *)
      echo "Usage: $0 [--base-ref <ref>] [--head-ref <ref>] [--require-release-note]" >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "✗ $*" >&2
  exit 1
}

first_line_matching() {
  local pattern="$1"
  awk -v pattern="$pattern" '$0 ~ pattern { print NR; exit }'
}

echo "▸ Checking bundled changelog sync…"
./scripts/sync-changelog-resource.sh --check

echo "▸ Checking shell script syntax…"
bash -n scripts/*.sh

echo "▸ Checking workflow YAML syntax…"
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' .github/workflows/*.yml

echo "▸ Checking wiki docs…"
ruby -c scripts/wiki-tool.rb >/dev/null
./scripts/wiki-check.sh

echo "▸ Checking release-note composition…"
base="$(./scripts/version-info.sh base)"
build="$(./scripts/version-info.sh build)"
sha="$(./scripts/version-info.sh sha)"

stable_notes="$(CHANNEL=stable VERSION_VALUE="$base" ./scripts/release-body.sh)"
stable_full_line="$(printf '%s\n' "$stable_notes" | first_line_matching '^## Full Release Notes$')"
stable_changes_line="$(printf '%s\n' "$stable_notes" | first_line_matching '^## Changes Since Last')"
[ -n "$stable_full_line" ] || fail "stable release notes are missing Full Release Notes"
[ "$stable_full_line" -eq 1 ] || fail "stable release notes must start with Full Release Notes"
[ -z "$stable_changes_line" ] || fail "stable release notes must not include Changes Since Last"

beta_version="$base-beta.$build+$sha"
beta_notes="$(CHANNEL=beta VERSION_VALUE="$beta_version" ./scripts/release-body.sh)"
beta_changes_line="$(printf '%s\n' "$beta_notes" | first_line_matching '^## Changes Since Last Beta$')"
beta_full_line="$(printf '%s\n' "$beta_notes" | first_line_matching '^## Full Release Notes$')"
[ -n "$beta_changes_line" ] || fail "beta release notes are missing Changes Since Last Beta"
[ -n "$beta_full_line" ] || fail "beta release notes are missing Full Release Notes"
[ "$beta_changes_line" -lt "$beta_full_line" ] || fail "beta changes must appear before full release notes"

nightly_version="$base-nightly.$build+$sha"
nightly_notes="$(CHANNEL=nightly VERSION_VALUE="$nightly_version" ./scripts/release-body.sh)"
nightly_changes_line="$(printf '%s\n' "$nightly_notes" | first_line_matching '^## Changes Since Last Nightly$')"
nightly_full_line="$(printf '%s\n' "$nightly_notes" | first_line_matching '^## Full Release Notes$')"
[ -n "$nightly_changes_line" ] || fail "nightly release notes are missing Changes Since Last Nightly"
[ -n "$nightly_full_line" ] || fail "nightly release notes are missing Full Release Notes"
[ "$nightly_changes_line" -lt "$nightly_full_line" ] || fail "nightly changes must appear before full release notes"

if $require_release_note; then
  echo "▸ Checking PR release-note coverage…"
  BASE_REF="$base_ref" HEAD_REF="$head_ref" ./scripts/require-release-note.sh
fi

echo "✓ CI validation passed."
