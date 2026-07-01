#!/usr/bin/env bash
# Fixture coverage for wiki marker validation, rendering, and promotion helpers.
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
tmp="$(mktemp -d .release/wiki-tests.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

echo "▸ Checking wiki rendering..."
source_dir="$tmp/source"
mkdir -p "$source_dir"
cat > "$source_dir/Home.md" <<'MARKDOWN'
# Home

See [[Details]].

<!-- wiki:section id="update-channel-picker" -->
## Update Channels

Stable behavior.
<!-- /wiki:section -->

<!-- wiki:variant id="update-channel-picker" channel="nightly" since="1.1.0" -->
### [Nightly] Update Channels

Nightly behavior.
<!-- /wiki:variant -->
MARKDOWN
cat > "$source_dir/Details.md" <<'MARKDOWN'
# Details

Everything else.
MARKDOWN

./scripts/wiki-check.sh --source "$source_dir"
./scripts/wiki-render.sh --source "$source_dir" --output "$tmp/rendered-nightly" --channel nightly >/dev/null
nightly_output="$(cat "$tmp/rendered-nightly/Home.md")"
assert_contains "$nightly_output" "Deprecating in 1.1.0" "nightly render"
assert_contains "$nightly_output" "### [Nightly] Update Channels" "nightly render"
assert_not_contains "$nightly_output" "wiki:section" "nightly render"

./scripts/wiki-render.sh --source "$source_dir" --output "$tmp/rendered-stable" --channel stable >/dev/null
stable_output="$(cat "$tmp/rendered-stable/Home.md")"
assert_not_contains "$stable_output" "[Nightly]" "stable render"
assert_not_contains "$stable_output" "Deprecating" "stable render"

echo "▸ Checking wiki validation failures..."
bad_dir="$tmp/bad"
mkdir -p "$bad_dir"
cat > "$bad_dir/Home.md" <<'MARKDOWN'
# Home

See [[Missing]].

<!-- wiki:section id="duplicate" -->
## One
<!-- /wiki:section -->

<!-- wiki:section id="duplicate" -->
## Two
<!-- /wiki:section -->

<!-- wiki:variant id="unknown" channel="nightly" since="1.1.0" -->
### [Nightly] Unknown
<!-- /wiki:variant -->
MARKDOWN
if ./scripts/wiki-check.sh --source "$bad_dir" >/dev/null 2>&1; then
  fail "wiki-check accepted invalid markers"
fi

echo "▸ Checking wiki promotion..."
promote_dir="$tmp/promote"
mkdir -p "$promote_dir"
cat > "$promote_dir/Page.md" <<'MARKDOWN'
# Page

<!-- wiki:section id="panel-flow" -->
## Panel Flow

Stable flow.
<!-- /wiki:section -->

<!-- wiki:variant id="panel-flow" channel="nightly" since="1.2.0" -->
### [Nightly] Panel Flow

Nightly flow.
<!-- /wiki:variant -->
MARKDOWN

./scripts/wiki-promote.sh --source "$promote_dir" --from nightly --to beta >/dev/null
promoted_beta="$(cat "$promote_dir/Page.md")"
assert_contains "$promoted_beta" 'channel="beta"' "nightly to beta promotion"
assert_contains "$promoted_beta" "### [Beta] Panel Flow" "nightly to beta promotion"
assert_not_contains "$promoted_beta" "[Nightly]" "nightly to beta promotion"

./scripts/wiki-promote.sh --source "$promote_dir" --from beta --to stable >/dev/null
promoted_stable="$(cat "$promote_dir/Page.md")"
assert_contains "$promoted_stable" "Nightly flow." "beta to stable promotion"
assert_not_contains "$promoted_stable" "Stable flow." "beta to stable promotion"
assert_not_contains "$promoted_stable" "wiki:variant" "beta to stable promotion"
assert_not_contains "$promoted_stable" "[Beta]" "beta to stable promotion"

echo "▸ Checking wiki publish preservation..."
publish_rendered="$tmp/publish-rendered"
publish_remote="$tmp/publish-remote"
mkdir -p "$publish_rendered" "$publish_remote/.git"
printf '%s\n' '# Home' > "$publish_rendered/Home.md"
printf '%s\n' 'remote footer' > "$publish_remote/_Footer.md"
printf '%s\n' '# Old Page' > "$publish_remote/Old.md"
rsync -a --delete --exclude='.git/' --exclude='_Footer.md' "$publish_rendered/" "$publish_remote/"
[ -f "$publish_remote/_Footer.md" ] || fail "wiki publish removed _Footer.md"
[ ! -f "$publish_remote/Old.md" ] || fail "wiki publish kept stale managed page"
[ -f "$publish_remote/Home.md" ] || fail "wiki publish did not copy rendered page"

echo "✓ Wiki script fixture tests passed."
