#!/usr/bin/env bash
# Run repository, release, Swift, and generated-file checks.
# Usage: ./Scripts/check.sh <doctor|repo|swift|release|generated|all> [...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

base_ref=""
head_ref="HEAD"
require_release_note=false

fail() {
  echo "✗ $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./Scripts/check.sh doctor
  ./Scripts/check.sh repo [--base-ref <ref>] [--head-ref <ref>] [--require-release-note]
  ./Scripts/check.sh swift
  ./Scripts/check.sh release
  ./Scripts/check.sh generated
  ./Scripts/check.sh all [--base-ref <ref>] [--head-ref <ref>] [--require-release-note]
USAGE
}

parse_repo_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --base-ref)
        base_ref="${2:-}"
        [ -n "$base_ref" ] || fail "--base-ref requires a value"
        shift 2
        ;;
      --head-ref)
        head_ref="${2:-}"
        [ -n "$head_ref" ] || fail "--head-ref requires a value"
        shift 2
        ;;
      --require-release-note)
        require_release_note=true
        shift
        ;;
      *)
        usage
        exit 2
        ;;
    esac
  done
}

first_line_matching() {
  local pattern="$1"
  awk -v pattern="$pattern" '$0 ~ pattern { print NR; exit }'
}

check_no_matches() {
  local label="$1"
  local pattern="$2"
  shift 2
  local output
  output="$(rg -n "$pattern" "$@" 2>/dev/null || true)"
  if [ -n "$output" ]; then
    printf '✗ %s:\n%s\n' "$label" "$output" >&2
    exit 1
  fi
}

doctor_checks() {
  swift --version
  xcodebuild -version
  git --version
  ruby --version
  rg --version | sed -n '1p'
}

generated_checks() {
  git update-index -q --refresh

  if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
    echo "✗ Tracked files changed unexpectedly:" >&2
    git status --short >&2
    exit 1
  fi

  echo "✓ No tracked generated-file drift."
}

swift_checks() {
  swift build
  swift test
}

require_release_note_check() {
  if [ "${NO_RELEASE_NOTE:-}" = "1" ]; then
    echo "✓ Release-note requirement skipped by NO_RELEASE_NOTE=1."
    return 0
  fi

  [ -n "$base_ref" ] || fail "BASE_REF is required for release-note enforcement"
  git rev-parse --verify "$base_ref" >/dev/null 2>&1 || fail "Base ref '$base_ref' was not found"
  git rev-parse --verify "$head_ref" >/dev/null 2>&1 || fail "Head ref '$head_ref' was not found"

  local changed_files
  changed_files="$(git diff --name-only --diff-filter=ACMR "$base_ref...$head_ref")"
  if [ -z "$changed_files" ]; then
    echo "✓ No changed files to inspect for release notes."
    return 0
  fi

  local has_note=false
  local has_material_change=false

  while IFS= read -r file; do
    [ -n "$file" ] || continue

    case "$file" in
      CHANGELOG.md|Sources/ContainedApp/Resources/CHANGELOG.md|Changes/Current.md|Changes/Beta.md|Changes/*.md)
        has_note=true
        ;;
    esac

    case "$file" in
      Package.swift|Package.resolved|VERSION|Sources/**|Tests/**|Packages/**|Resources/**|Scripts/**|.github/workflows/**)
        has_material_change=true
        ;;
    esac
  done <<< "$changed_files"

  if $has_material_change && ! $has_note; then
    echo "✗ Material changes need a release note." >&2
    echo >&2
    echo "Changed files:" >&2
    while IFS= read -r file; do
      [ -n "$file" ] && printf '  %s\n' "$file" >&2
    done <<< "$changed_files"
    echo >&2
    echo "Add one of:" >&2
    echo "  - Changes/Current.md for PR/build-level notes" >&2
    echo "  - CHANGELOG.md plus synced Sources/ContainedApp/Resources/CHANGELOG.md for curated version notes" >&2
    echo >&2
    echo "For documentation, metadata, or dependency-only maintenance, apply the 'no-release-note' PR label so CI sets NO_RELEASE_NOTE=1." >&2
    exit 1
  fi

  echo "✓ Release-note requirement passed."
}

repo_checks() {
  echo "▸ Checking bundled changelog sync..."
  cmp -s CHANGELOG.md Sources/ContainedApp/Resources/CHANGELOG.md \
    || fail "Bundled changelog is out of sync. Run ./Scripts/package.sh app debug and commit the synced resource."

  echo "▸ Checking shell script syntax..."
  bash -n Scripts/*.sh

  echo "▸ Checking shell script strict mode..."
  for script in Scripts/*.sh; do
    [ "$(sed -n '1p' "$script")" = '#!/usr/bin/env bash' ] || fail "$script must start with #!/usr/bin/env bash"
    rg -q '^set -euo pipefail$' "$script" || fail "$script must enable set -euo pipefail"
    rg -q '^# .+' "$script" || fail "$script must document one purpose"
    rg -q '^# Usage:' "$script" || fail "$script must document usage"
  done

  echo "▸ Checking workflow YAML syntax..."
  ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' .github/workflows/*.yml

  echo "▸ Checking workflow path filters..."
  release_meta_paths=(
    'Documentation/**'
    'README.md'
    'Packages/*/README.md'
    'Packages/*/Sources/*/*.docc/**'
    'Changes/**'
    'CODE_OF_CONDUCT.md'
    '.github/*.md'
    '.github/ISSUE_TEMPLATE/**'
    '.github/assets/**'
    '.github/dependabot.yml'
    'CODEOWNERS'
    'LICENSE'
    'NOTICE'
    'SECURITY.md'
    'SUPPORT.md'
    '.gitignore'
    'appcast.xml'
  )
  for workflow in .github/workflows/nightly.yml .github/workflows/beta.yml .github/workflows/stable.yml; do
    for pattern in "${release_meta_paths[@]}"; do
      rg -Fq -- "- '$pattern'" "$workflow" || fail "$workflow paths-ignore is missing $pattern"
    done
  done
  for pattern in "${release_meta_paths[@]}"; do
    rg -Fq -- "$pattern" .github/workflows/pr.yml || fail ".github/workflows/pr.yml material classifier is missing $pattern"
  done
  codeql_meta_paths=(
    "${release_meta_paths[@]}"
    'CHANGELOG.md'
    'Sources/ContainedApp/Resources/CHANGELOG.md'
  )
  for pattern in "${codeql_meta_paths[@]}"; do
    matches="$(rg -F -- "- '$pattern'" .github/workflows/codeql.yml | wc -l | tr -d ' ')"
    [ "$matches" -ge 2 ] || fail ".github/workflows/codeql.yml paths-ignore is missing $pattern in pull_request or push"
  done
  for workflow in .github/workflows/pr.yml .github/workflows/nightly.yml .github/workflows/beta.yml .github/workflows/stable.yml; do
    rg -Fq 'timeout-minutes: 30' "$workflow" || fail "$workflow must cap macOS job runtime with timeout-minutes: 30"
  done

  echo "▸ Checking local Markdown links..."
  ruby <<'RUBY'
root = Dir.pwd
files = [
  "README.md",
  "AGENTS.md",
  ".github/CONTRIBUTING.md",
  ".github/pull_request_template.md",
  *Dir["Documentation/**/*.md"],
  *Dir["Packages/*/README.md"],
  *Dir["Packages/*/Sources/*/*.docc/*.md"]
].uniq

failed = false
files.each do |file|
  next if file == "Documentation/Wiki/_Sidebar.md"
  text = File.read(file)
  text.scan(/!?\[[^\]]*\]\(([^)]+)\)/).flatten.each do |target|
    next if target.start_with?("http://", "https://", "mailto:", "#")
    clean = target.split("#", 2).first.split("?", 2).first
    next if clean.empty?
    path = if clean.start_with?("/")
      File.join(root, clean.delete_prefix("/"))
    else
      File.expand_path(clean, File.dirname(File.join(root, file)))
    end
    next if File.exist?(path)
    warn "✗ #{file} links to missing local path #{target}"
    failed = true
  end
end
exit(failed ? 1 : 0)
RUBY

  echo "▸ Checking wiki map coverage..."
  local wiki_map="Documentation/Wiki/File-Map.md"
  local wiki_sidebar="Documentation/Wiki/_Sidebar.md"
  [ -f "$wiki_map" ] || fail "missing $wiki_map"
  [ -f "$wiki_sidebar" ] || fail "missing $wiki_sidebar"

  required_docs=()
  while IFS= read -r doc; do
    required_docs+=("$doc")
  done < <(find Documentation/App Documentation/Features Documentation/Architecture Documentation/Development Documentation/Release -type f -name '*.md' | sort)
  while IFS= read -r doc; do
    required_docs+=("$doc")
  done < <(find Packages \( -path '*/.build' -o -path '*/.swiftpm' \) -prune -o \( -path 'Packages/*/README.md' -o -path 'Packages/*/Sources/*/*.docc/*.md' \) -type f -print | sort)
  for doc in "${required_docs[@]}"; do
    [ -f "$doc" ] || fail "mapped documentation source is missing: $doc"
    case "$doc" in
      Documentation/*) docs_index_target="${doc#Documentation/}" ;;
      *) docs_index_target="../$doc" ;;
    esac
    rg -Fq "($docs_index_target)" Documentation/README.md || fail "Documentation/README.md is missing $doc"
    rg -Fq "\`$doc\`" "$wiki_map" || fail "$wiki_map is missing $doc"
  done
  while IFS='|' read -r _ source target _; do
    source="$(sed 's/^ *//; s/ *$//' <<< "$source")"
    target="$(sed 's/^ *//; s/ *$//' <<< "$target")"
    [[ "$source" == \`* ]] || continue
    source="${source#\`}"; source="${source%\`}"
    target="${target#\`}"; target="${target%\`}"
    [ -f "$source" ] || fail "$wiki_map points to missing source $source"
    rg -Fq "$target" "$wiki_sidebar" || fail "$wiki_sidebar is missing mapped target $target"
  done < "$wiki_map"

  echo "▸ Checking stale path references..."
  check_no_matches "lowercase scripts path references" '(^|[^A-Za-z])(\./)?scripts/' README.md AGENTS.md Documentation Packages Sources Tests .github CODEOWNERS Package.swift Contained.xcodeproj
  check_no_matches "lowercase docs path references" '(^|[^A-Za-z])(/)?docs/' README.md AGENTS.md Documentation Packages Sources Tests .github CODEOWNERS Package.swift
  check_no_matches "old wiki path references" 'docs/wiki' README.md AGENTS.md Documentation Packages Sources Tests .github CODEOWNERS Package.swift
  check_no_matches "old change-fragment path references" 'changes/(unreleased|beta|nightly)|changes/\*\*|Changes/unrelease[d]' README.md AGENTS.md Documentation Packages Sources Tests .github CODEOWNERS Package.swift Scripts

  echo "▸ Checking package boundary and naming invariants..."
  check_no_matches "stale package names" '\b(ContainedDesignSystem|ContainedNavigation|ContainedRuntime|AppleContainerRuntime|ContainedPreviewSupport)\b' README.md AGENTS.md Documentation Packages Sources Tests .github
  check_no_matches "stale flat public names" '\b(DesignCard|DesignTokens|PanelHeader|SheetHeader|LiveSparkline|ErrorToast|ResourceGlassCard|ResourceCardHeader|RuntimeKind|RuntimeDescriptor|RuntimeCapability|RuntimeCommandPreview|RuntimeComposeImportPlan|RuntimeCoreSwitchPlan|ContainerCreateRequest|ContainerCreateResult|ContainerSnapshot)\b' README.md AGENTS.md Documentation Packages Sources Tests .github
  check_no_matches "stale refactor wording" '\b(refactor history|compatibility alias|compatibility aliases|temporary migration|legacy compatibility|bridge wrappers|old package|Migrated to|WS[0-9]+|previous bundle name|older build folders)\b' README.md AGENTS.md Documentation Packages Sources Tests .github
  check_no_matches "app adapter internals" '\b(ContainerCommands|DockerCommands|AppleContainerClient|DockerClient|AppleContainerCLILocator|DockerCLILocator|AppleContainerCreateTranslator|DockerCreateTranslator)\b' Sources/ContainedApp Tests/ContainedAppTests Documentation .github
  check_no_matches "Core imports UI/UX/app-only dependencies" '^import (ContainedUI|ContainedUX|SwiftUI|Sparkle|SwiftTerm)$' Packages/ContainedCore/Sources/ContainedCore
  check_no_matches "UI imports Core/UX/App" '^import (ContainedCore|ContainedUX|ContainedApp|Sparkle|SwiftTerm)$' Packages/ContainedUI/Sources/ContainedUI
  check_no_matches "UX imports Core/App" '^import (ContainedCore|ContainedApp|Sparkle|SwiftTerm)$' Packages/ContainedUX/Sources/ContainedUX
  raw_token_output="$(rg -n --glob '*.swift' '\bUI\.Tokens\b' Sources/ContainedApp Packages/ContainedUX/Sources Tests 2>/dev/null || true)"
  if [ -n "$raw_token_output" ]; then
    printf '✗ raw UI.Tokens outside ContainedUI source:\n%s\n' "$raw_token_output" >&2
    exit 1
  fi
  empty_dirs="$(find Packages Sources Tests Documentation -path '*/.build' -prune -o -path '*/.swiftpm' -prune -o -type d -empty -print)"
  [ -z "$empty_dirs" ] || fail "empty source/docs folders found: $empty_dirs"

  if $require_release_note; then
    echo "▸ Checking PR release-note coverage..."
    require_release_note_check
  fi

  echo "✓ Repository validation passed."
}

release_checks() {
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
  local tmp
  tmp="$(mktemp -d .release/test-release-scripts.XXXXXX)"
  trap 'rm -rf "$tmp"' RETURN

  echo "▸ Checking package version validation..."
  if BUILD=abc ./Scripts/package.sh version build >/dev/null 2>&1; then
    fail "package version accepted a non-numeric BUILD"
  fi

  env_output="$(CHANNEL=beta BUILD=123 SHA=abcdef0 BASE_VERSION=9.8.7 ./Scripts/package.sh version env)"
  assert_contains "$env_output" "BASE_VERSION=9.8.7" "package version env"
  assert_contains "$env_output" "BUILD=123" "package version env"
  assert_contains "$env_output" "SHA=abcdef0" "package version env"
  assert_contains "$env_output" "VERSION=9.8.7-beta.123+abcdef0" "package version env"

  echo "▸ Checking release-note composition..."
  local fixture_changelog="$tmp/CHANGELOG.md"
  local current_changes="$tmp/Current.md"
  local beta_changes="$tmp/Beta.md"
  local empty_changes="$tmp/Empty.md"
  cat > "$fixture_changelog" <<'MARKDOWN'
# Changelog

## [Unreleased] - Current Build

### Fixed

- Build-specific fallback fix.

## [9.8.7] - Version Notes

### Added

- Version-wide feature.
MARKDOWN
  printf '%s\n' '### Current' '' '- Current nightly fix.' > "$current_changes"
  printf '%s\n' '### Beta' '' '- Accumulated beta fix.' > "$beta_changes"
  : > "$empty_changes"

  stable_notes="$(CHANGELOG="$fixture_changelog" RELEASE_NOTES="$fixture_changelog" CHANGES="$empty_changes" VERSION_VALUE=9.8.7 CHANNEL=stable ./Scripts/notes.sh body)"
  assert_contains "$stable_notes" "## Full Release Notes" "stable notes"
  assert_contains "$stable_notes" "Version-wide feature." "stable notes"
  assert_not_contains "$stable_notes" "Changes Since Last" "stable notes"

  stable_hotfix_notes="$(CHANGELOG="$fixture_changelog" RELEASE_NOTES="$fixture_changelog" CURRENT_CHANGES_FILE="$current_changes" VERSION_VALUE=9.8.7 CHANNEL=stable ./Scripts/notes.sh body)"
  assert_contains "$stable_hotfix_notes" "## Changes In This Build" "stable hotfix notes"
  assert_contains "$stable_hotfix_notes" "Current nightly fix." "stable hotfix notes"

  beta_notes="$(CHANGELOG="$fixture_changelog" RELEASE_NOTES="$fixture_changelog" CHANGES="$beta_changes" VERSION_VALUE=9.8.7-beta.123+abcdef0 CHANNEL=beta ./Scripts/notes.sh body)"
  assert_contains "$beta_notes" "## Changes Since Last Beta" "beta notes"
  assert_contains "$beta_notes" "Accumulated beta fix." "beta notes"
  assert_contains "$beta_notes" "## Full Release Notes" "beta notes"
  assert_contains "$beta_notes" "Version-wide feature." "beta notes"

  nightly_notes="$(CHANGELOG="$fixture_changelog" RELEASE_NOTES="$fixture_changelog" CHANGES="$current_changes" VERSION_VALUE=9.8.7-nightly.123+abcdef0 CHANNEL=nightly ./Scripts/notes.sh body)"
  assert_contains "$nightly_notes" "## Changes Since Last Nightly" "nightly notes"
  assert_contains "$nightly_notes" "Current nightly fix." "nightly notes"
  assert_contains "$nightly_notes" "## Full Release Notes" "nightly notes"

  echo "▸ Checking rolling-note finalization..."
  local finalize_current="$tmp/finalize-current.md"
  local finalize_beta="$tmp/finalize-beta.md"
  printf '%s\n' '### First' '' '- Current content.' > "$finalize_current"
  printf '%s\n' '### Existing' '' '- Existing beta content.' > "$finalize_beta"
  CURRENT_CHANGES_FILE="$finalize_current" BETA_CHANGES_FILE="$finalize_beta" ./Scripts/notes.sh finalize nightly >/dev/null
  [ ! -s "$finalize_current" ] || fail "nightly finalize did not clear current notes"
  assert_contains "$(cat "$finalize_beta")" "Current content." "nightly finalized beta"
  assert_contains "$(cat "$finalize_beta")" "Existing beta content." "nightly finalized beta"
  CURRENT_CHANGES_FILE="$finalize_current" BETA_CHANGES_FILE="$finalize_beta" ./Scripts/notes.sh finalize beta >/dev/null
  [ ! -s "$finalize_beta" ] || fail "beta finalize did not clear beta notes"
  printf '%s\n' '- Hotfix.' > "$finalize_current"
  CURRENT_CHANGES_FILE="$finalize_current" ./Scripts/notes.sh finalize stable >/dev/null
  [ ! -s "$finalize_current" ] || fail "stable finalize did not clear current notes"

  echo "▸ Checking note collection and HTML rendering..."
  mkdir -p "$tmp/changes" "$tmp/updates"
  printf '%s\n' '- Second fragment.' > "$tmp/changes/20260701-b.md"
  printf '%s\n' '- First fragment.' > "$tmp/changes/20260701-a.md"
  fragment_output="$(./Scripts/notes.sh collect "$tmp/changes")"
  assert_contains "$fragment_output" "- First fragment." "note collection"
  assert_contains "$fragment_output" "- Second fragment." "note collection"
  : > "$tmp/updates/Contained-test.dmg"
  CHANNEL=nightly VERSION_VALUE=9.8.7-nightly.123+abcdef0 CHANGELOG="$fixture_changelog" RELEASE_NOTES="$fixture_changelog" CHANGES="$current_changes" ./Scripts/notes.sh html "$tmp/updates" >/dev/null
  [ -f "$tmp/updates/Contained-test.html" ] || fail "notes html did not write archive sibling"

  echo "▸ Checking automatic channel deltas..."
  local no_delta_appcast="$tmp/no-delta-nightly.xml"
  local head_sha
  head_sha="$(git rev-parse --short HEAD)"
  cat > "$no_delta_appcast" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Contained</title>
    <item>
      <title>1.0.0-nightly.999+${head_sha}</title>
      <sparkle:version>999</sparkle:version>
      <sparkle:shortVersionString>1.0.0-nightly.999+${head_sha}</sparkle:shortVersionString>
      <description>Current nightly notes.</description>
      <enclosure url="https://example.com/Contained.dmg" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
  no_delta_notes="$(APPCAST="$no_delta_appcast" CHANNEL=nightly ./Scripts/notes.sh delta)"
  assert_contains "$no_delta_notes" "No channel-specific changes were recorded for this build." "empty automatic nightly notes"

  echo "▸ Checking appcast promotion and validation..."
  local promoted="$tmp/promoted.xml"
  local beta_only="$tmp/beta.xml"
  local stable_only="$tmp/stable.xml"
  local nightly="$tmp/nightly.xml"
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

  CHANNEL=beta ./Scripts/appcast.sh validate "$beta_only" >/dev/null
  CHANNEL=stable ./Scripts/appcast.sh validate "$stable_only" >/dev/null
  ./Scripts/appcast.sh promote --non-nightly-only "$promoted" "$nightly" >/dev/null
  promoted_output="$(cat "$nightly")"
  assert_contains "$promoted_output" "9.8.7-beta.123+abcdef0" "promoted appcast"
  assert_not_contains "$promoted_output" "9.8.7-nightly.124+abcdef1" "promoted appcast"
  CHANNEL=nightly ./Scripts/appcast.sh validate "$nightly" >/dev/null

  echo "✓ Release script fixture tests passed."
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

case "$command" in
  doctor)
    doctor_checks
    ;;
  repo)
    parse_repo_args "$@"
    repo_checks
    ;;
  swift)
    swift_checks
    ;;
  release)
    release_checks
    ;;
  generated)
    generated_checks
    ;;
  all)
    parse_repo_args "$@"
    doctor_checks
    repo_checks
    release_checks
    swift_checks
    generated_checks
    ;;
  *)
    usage
    exit 2
    ;;
esac
