#!/usr/bin/env bash
# Fast repository checks shared by PR and release workflows.
# Usage: ./scripts/ci-validate.sh [--base-ref <ref>] [--head-ref <ref>] [--require-release-note]
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

check_no_matches() {
  local label="$1"
  local pattern="$2"
  shift 2
  local output
  output="$(rg -n --glob '!scripts/ci-validate.sh' "$pattern" "$@" 2>/dev/null || true)"
  if [ -n "$output" ]; then
    printf '✗ %s:\n%s\n' "$label" "$output" >&2
    exit 1
  fi
}

echo "▸ Checking bundled changelog sync…"
./scripts/sync-changelog-resource.sh --check

echo "▸ Checking shell script syntax…"
bash -n scripts/*.sh

echo "▸ Checking shell script strict mode…"
for script in scripts/*.sh; do
  [ "$(sed -n '1p' "$script")" = '#!/usr/bin/env bash' ] || fail "$script must start with #!/usr/bin/env bash"
  rg -q '^set -euo pipefail$' "$script" || fail "$script must enable set -euo pipefail"
  rg -q '^# .+' "$script" || fail "$script must document one purpose"
  rg -q '^# Usage:' "$script" || fail "$script must document usage"
done

echo "▸ Checking workflow YAML syntax…"
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' .github/workflows/*.yml

echo "▸ Checking workflow path filters…"
release_meta_paths=(
  'docs/**'
  'README.md'
  'Packages/*/README.md'
  'Packages/*/Sources/*/*.docc/**'
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
  'changes/**'
)
for pattern in "${codeql_meta_paths[@]}"; do
  matches="$(rg -F -- "- '$pattern'" .github/workflows/codeql.yml | wc -l | tr -d ' ')"
  [ "$matches" -ge 2 ] || fail ".github/workflows/codeql.yml paths-ignore is missing $pattern in pull_request or push"
done

echo "▸ Checking local Markdown links…"
ruby <<'RUBY'
root = Dir.pwd
files = [
  "README.md",
  "AGENTS.md",
  ".github/CONTRIBUTING.md",
  ".github/pull_request_template.md",
  *Dir["docs/**/*.md"],
  *Dir["Packages/*/README.md"],
  *Dir["Packages/*/Sources/*/*.docc/*.md"]
].uniq

failed = false
files.each do |file|
  next if file == "docs/wiki/_Sidebar.md"
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

echo "▸ Checking wiki map coverage…"
wiki_map="docs/wiki/File-Map.md"
wiki_sidebar="docs/wiki/_Sidebar.md"
[ -f "$wiki_map" ] || fail "missing $wiki_map"
[ -f "$wiki_sidebar" ] || fail "missing $wiki_sidebar"
required_docs=()
while IFS= read -r doc; do
  required_docs+=("$doc")
done < <(find docs/app docs/features docs/architecture docs/development docs/release -type f -name '*.md' | sort)
while IFS= read -r doc; do
  required_docs+=("$doc")
done < <(find Packages \( -path '*/.build' -o -path '*/.swiftpm' \) -prune -o \( -path 'Packages/*/README.md' -o -path 'Packages/*/Sources/*/*.docc/*.md' \) -type f -print | sort)
for doc in "${required_docs[@]}"; do
  [ -f "$doc" ] || fail "mapped documentation source is missing: $doc"
  case "$doc" in
    docs/*) docs_index_target="${doc#docs/}" ;;
    *) docs_index_target="../$doc" ;;
  esac
  rg -Fq "($docs_index_target)" docs/README.md || fail "docs/README.md is missing $doc"
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

echo "▸ Checking package boundary and naming invariants…"
check_no_matches "stale package names" '\b(ContainedDesignSystem|ContainedNavigation|ContainedRuntime|AppleContainerRuntime|ContainedPreviewSupport)\b' README.md AGENTS.md docs Packages Sources Tests .github
check_no_matches "stale flat public names" '\b(DesignCard|DesignTokens|PanelHeader|SheetHeader|LiveSparkline|ErrorToast|ResourceGlassCard|ResourceCardHeader|RuntimeKind|RuntimeDescriptor|RuntimeCapability|RuntimeCommandPreview|RuntimeComposeImportPlan|RuntimeCoreSwitchPlan|ContainerCreateRequest|ContainerCreateResult|ContainerSnapshot)\b' README.md AGENTS.md docs Packages Sources Tests .github
check_no_matches "stale refactor wording" '\b(refactor history|compatibility alias|compatibility aliases|temporary migration|legacy compatibility|bridge wrappers|old package|Migrated to|WS[0-9]+|previous bundle name|older build folders)\b' README.md AGENTS.md docs Packages Sources Tests scripts .github
check_no_matches "app adapter internals" '\b(ContainerCommands|AppleContainerClient|AppleContainerCLILocator|ContainerRuntimeClient)\b' Sources/ContainedApp Tests/ContainedAppTests docs .github
check_no_matches "Core imports UI/UX/app-only dependencies" '^import (ContainedUI|ContainedUX|SwiftUI|Sparkle|SwiftTerm)$' Packages/ContainedCore/Sources/ContainedCore
check_no_matches "UI imports Core/UX/App" '^import (ContainedCore|ContainedUX|ContainedApp|Sparkle|SwiftTerm)$' Packages/ContainedUI/Sources/ContainedUI
check_no_matches "UX imports Core/App" '^import (ContainedCore|ContainedApp|Sparkle|SwiftTerm)$' Packages/ContainedUX/Sources/ContainedUX
raw_token_output="$(rg -n --glob '*.swift' '\bUI\.Tokens\b' Sources/ContainedApp Packages/ContainedUX/Sources Tests 2>/dev/null || true)"
if [ -n "$raw_token_output" ]; then
  printf '✗ raw UI.Tokens outside ContainedUI source:\n%s\n' "$raw_token_output" >&2
  exit 1
fi
[ -z "$(find Packages Sources Tests docs -path '*/.build' -prune -o -path '*/.swiftpm' -prune -o -type d -empty -print)" ] || fail "empty source/docs folders found"

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
