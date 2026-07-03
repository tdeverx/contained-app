#!/usr/bin/env bash
# Compose, render, collect, and finalize rolling release notes.
# Usage: ./Scripts/notes.sh <body|html|delta|collect|finalize> [...]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "✗ $*" >&2
  exit 1
}

usage() {
  cat >&2 <<'USAGE'
Usage:
  ./Scripts/notes.sh body
  ./Scripts/notes.sh html [updates-dir]
  ./Scripts/notes.sh delta [stable|beta|nightly] [head-ref]
  ./Scripts/notes.sh collect [<git-range>] <file-or-dir> [...]
  ./Scripts/notes.sh finalize <nightly|beta|stable>
USAGE
}

trim_markdown() {
  ruby -e '
text = STDIN.read.lines.map(&:rstrip).join("\n")
text = text.gsub(/\A\s+/, "").gsub(/\s+\z/, "")
puts text unless text.empty?
'
}

file_has_content() {
  local file="$1"
  [ -f "$file" ] || return 1
  ruby -e 'exit(File.read(ARGV.fetch(0)).strip.empty? ? 1 : 0)' "$file"
}

read_markdown_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  trim_markdown < "$file"
}

extract_section() {
  local file="$1"
  local version="$2"
  awk -v version="$version" '
    BEGIN { in_section=0 }
    /^## / {
      if (in_section) exit
      if (index($0, version) > 0 || index($0, "[" version "]") > 0) { in_section=1; next }
    }
    in_section { print }
  ' "$file" | trim_markdown
}

channel_title() {
  case "$1" in
    beta) printf 'Beta' ;;
    nightly) printf 'Nightly' ;;
    *) printf 'Release' ;;
  esac
}

default_changes_file() {
  case "$1" in
    nightly) printf '%s\n' "${CURRENT_CHANGES_FILE:-Changes/Current.md}" ;;
    beta) printf '%s\n' "${BETA_CHANGES_FILE:-Changes/Beta.md}" ;;
    stable) printf '%s\n' "${CURRENT_CHANGES_FILE:-Changes/Current.md}" ;;
    *) return 1 ;;
  esac
}

collect_files() {
  local range=""
  local paths=()

  if [ "$#" -gt 0 ] && [[ "$1" == *..* ]]; then
    range="$1"
    shift
  fi
  paths=("$@")
  [ "${#paths[@]}" -gt 0 ] || paths=("Changes/Current.md")

  emit_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    read_markdown_file "$file"
    printf '\n'
  }

  for path in "${paths[@]}"; do
    case "$path" in
      ""|*..*)
        fail "notes paths must not contain '..': $path"
        ;;
    esac

    if [ -n "$range" ]; then
      git diff --name-only --diff-filter=AM "$range" -- "$path" \
        | LC_ALL=C sort -u \
        | while IFS= read -r file; do
            case "$file" in
              *.md) emit_file "$file" ;;
            esac
          done
    elif [ -d "$path" ]; then
      find "$path" -type f -name '*.md' \
        | LC_ALL=C sort \
        | while IFS= read -r file; do emit_file "$file"; done
    else
      emit_file "$path"
    fi
  done | trim_markdown
}

compose_body() {
  local changelog="${CHANGELOG:-CHANGELOG.md}"
  local release_notes_file="${RELEASE_NOTES:-$changelog}"
  local changes_file="${CHANGES:-}"
  local changes_dir="${CHANGES_DIR:-}"
  local changes_was_set="${CHANGES+x}"
  local changes_dir_was_set="${CHANGES_DIR+x}"
  local version_value="${VERSION_VALUE:-${VERSION:-$(cat VERSION 2>/dev/null || true)}}"
  local channel_value="${CHANNEL:-}"

  [ -f "$changelog" ] || fail "$changelog not found"
  [ -f "$release_notes_file" ] || fail "Release notes file '$release_notes_file' not found"
  [ -n "$version_value" ] || fail "VERSION is empty"

  local base="$version_value"
  base="${base%%+*}"
  base="${base%%-*}"

  if [ -z "$channel_value" ]; then
    case "$version_value" in
      *-nightly.*) channel_value="nightly" ;;
      *-beta.*) channel_value="beta" ;;
      *) channel_value="stable" ;;
    esac
  fi

  local full_fragment=""
  if [ "$base" != "$version_value" ]; then
    full_fragment="$(extract_section "$release_notes_file" "$base")"
  else
    full_fragment="$(extract_section "$release_notes_file" "$version_value")"
  fi
  if [ -z "$full_fragment" ] && [ "$base" != "$version_value" ]; then
    full_fragment="$(extract_section "$release_notes_file" "$version_value")"
  fi
  if [ -z "$full_fragment" ]; then
    full_fragment="$(extract_section "$release_notes_file" "Unreleased")"
  fi

  local changes_fragment=""
  if [ -n "$changes_dir" ]; then
    changes_fragment="$(collect_files "$changes_dir")"
  elif [ -n "$changes_file" ]; then
    changes_fragment="$(extract_section "$changes_file" "$version_value")"
    if [ -z "$changes_fragment" ]; then
      changes_fragment="$(extract_section "$changes_file" "$channel_value")"
    fi
    if [ -z "$changes_fragment" ]; then
      changes_fragment="$(extract_section "$changes_file" "Unreleased")"
    fi
    if [ -z "$changes_fragment" ]; then
      changes_fragment="$(read_markdown_file "$changes_file")"
    fi
  else
    case "$channel_value" in
      nightly|beta)
        changes_file="$(default_changes_file "$channel_value")"
        changes_fragment="$(read_markdown_file "$changes_file")"
        ;;
      stable)
        changes_file="$(default_changes_file stable)"
        changes_fragment="$(read_markdown_file "$changes_file")"
        ;;
    esac
  fi

  if [ -n "$changes_fragment" ]; then
    if [ "$channel_value" = "stable" ]; then
      if [ -n "$changes_was_set" ] || [ -n "$changes_dir_was_set" ]; then
        changes_fragment=""
      else
        printf '## Changes In This Build\n\n'
      fi
    else
      printf '## Changes Since Last %s\n\n' "$(channel_title "$channel_value")"
    fi
    if [ -n "$changes_fragment" ]; then
      printf '%s\n\n' "$changes_fragment"
    fi
  fi

  printf '## Full Release Notes\n\n'
  if [ -n "$full_fragment" ]; then
    printf '%s\n' "$full_fragment"
  else
    printf 'No full release notes were found for %s.\n' "$version_value"
  fi
}

write_html() {
  local updates_dir="${1:-updates}"
  local changelog="${CHANGELOG:-CHANGELOG.md}"
  local version_value="${VERSION_VALUE:-${VERSION:-$(cat VERSION 2>/dev/null || true)}}"

  [ -d "$updates_dir" ] || fail "Updates dir '$updates_dir' not found"
  [ -f "$changelog" ] || fail "$changelog not found"
  [ -n "$version_value" ] || fail "VERSION is empty"

  local fragment
  fragment="$(VERSION_VALUE="$version_value" CHANGELOG="$changelog" compose_body)"

  local html
  html="$(printf '%s\n' "$fragment" | awk '
    BEGIN { in_list=0 }
    /^## / {
      if (in_list) { print "</ul>"; in_list=0 }
      sub(/^## /, "")
      print "<h2>" $0 "</h2>"
      next
    }
    /^### / {
      if (in_list) { print "</ul>"; in_list=0 }
      sub(/^### /, "")
      print "<h3>" $0 "</h3>"
      next
    }
    /^#### / {
      if (in_list) { print "</ul>"; in_list=0 }
      sub(/^#### /, "")
      print "<h4>" $0 "</h4>"
      next
    }
    /^[[:space:]]*- / {
      if (!in_list) { print "<ul>"; in_list=1 }
      sub(/^[[:space:]]*- /, "")
      print "<li>" $0 "</li>"
      next
    }
    /^[[:space:]]*$/ {
      if (in_list) { print "</ul>"; in_list=0 }
      next
    }
    {
      if (in_list) { print "</ul>"; in_list=0 }
      print "<p>" $0 "</p>"
    }
    END { if (in_list) print "</ul>" }
  ')"

  local found=0
  for archive in "$updates_dir"/*.{dmg,zip,tar.gz,tgz}; do
    [ -e "$archive" ] || continue
    found=1
    local base="$archive"
    case "$base" in
      *.tar.gz) base="${base%.tar.gz}" ;;
      *) base="${base%.*}" ;;
    esac
    printf '%s\n' "$html" > "$base.html"
    echo "✓ Wrote ${base}.html"
  done

  [ "$found" -eq 1 ] || fail "No archives found in $updates_dir"
}

emit_delta() {
  local channel="${1:-${CHANNEL:-nightly}}"
  local head_ref="${2:-${HEAD_REF:-HEAD}}"
  local appcast="${APPCAST:-appcast.xml}"
  local changelog="${CHANGELOG:-CHANGELOG.md}"

  [ -f "$appcast" ] || exit 0

  local previous_ref
  previous_ref="$(
    APPCAST="$appcast" CHANNEL_VALUE="$channel" ruby <<'RUBY'
require "rexml/document"
require "rexml/xpath"

path = ENV.fetch("APPCAST")
channel = ENV.fetch("CHANNEL_VALUE")
namespaces = { "sparkle" => "http://www.andymatuschak.org/xml-namespaces/sparkle" }
doc = REXML::Document.new(File.read(path))

items = REXML::XPath.match(doc, "//item").map do |item|
  build = REXML::XPath.first(item, "sparkle:version", namespaces)&.text.to_s.strip
  short = REXML::XPath.first(item, "sparkle:shortVersionString", namespaces)&.text.to_s.strip
  next if build.empty? || short.empty?

  channel_match = case channel
                  when "nightly" then short.include?("-nightly.")
                  when "beta" then short.include?("-beta.")
                  when "stable" then !short.match?(/-(beta|nightly)\./)
                  else false
                  end
  next unless channel_match

  { build: build.to_i, short: short }
end.compact

selected = items.max_by { |item| item[:build] }
sha = selected&.dig(:short).to_s.split("+", 2)[1].to_s
puts sha if sha.match?(/\A[0-9a-f]{7,40}\z/)
RUBY
  )"

  [ -n "$previous_ref" ] || exit 0
  git rev-parse --verify "$previous_ref^{commit}" >/dev/null 2>&1 || exit 0
  git rev-parse --verify "$head_ref^{commit}" >/dev/null 2>&1 || exit 0

  local range="$previous_ref..$head_ref"
  mkdir -p .release
  local tmp
  tmp="$(mktemp -d .release/changes-since-release.XXXXXX)"
  trap 'rm -rf "$tmp"' RETURN

  for candidate in "Changes/Current.md" "Changes/Beta.md"; do
    if [ -e "$candidate" ]; then
      collect_files "$range" "$candidate" >> "$tmp/fragments.md"
    fi
  done

  if [ -s "$tmp/fragments.md" ]; then
    trim_markdown < "$tmp/fragments.md"
    exit 0
  fi

  case "$changelog" in
    ""|/*|*..*)
      echo "- No channel-specific changes were recorded for this build."
      exit 0
      ;;
  esac

  extract_unreleased() {
    awk '
      BEGIN { in_section=0 }
      /^## / {
        if (in_section) exit
        if (index($0, "Unreleased") > 0 || index($0, "[Unreleased]") > 0) { in_section=1; next }
      }
      in_section { print }
    '
  }

  git show "$previous_ref:$changelog" 2>/dev/null | extract_unreleased > "$tmp/old.md" || :
  if [ "$head_ref" = "HEAD" ] && [ -f "$changelog" ]; then
    extract_unreleased < "$changelog" > "$tmp/new.md"
  elif ! git show "$head_ref:$changelog" 2>/dev/null | extract_unreleased > "$tmp/new.md"; then
    extract_unreleased < "$changelog" > "$tmp/new.md"
  fi

  diff -U0 "$tmp/old.md" "$tmp/new.md" \
    | awk '/^\+/ && !/^\+\+\+/ { sub(/^\+/, ""); print }' \
    | trim_markdown > "$tmp/delta.md" || :

  if [ -s "$tmp/delta.md" ]; then
    cat "$tmp/delta.md"
  else
    echo "- No channel-specific changes were recorded for this build."
  fi
}

prepend_current_to_beta() {
  local current="${CURRENT_CHANGES_FILE:-Changes/Current.md}"
  local beta="${BETA_CHANGES_FILE:-Changes/Beta.md}"
  file_has_content "$current" || {
    echo "✓ No current release note content to roll into beta."
    return 0
  }

  local current_text
  local beta_text
  current_text="$(read_markdown_file "$current")"
  beta_text="$(read_markdown_file "$beta")"

  if [ -n "$beta_text" ]; then
    printf '%s\n\n%s\n' "$current_text" "$beta_text" > "$beta"
  else
    printf '%s\n' "$current_text" > "$beta"
  fi
  : > "$current"
  echo "✓ Rolled $current into $beta."
}

clear_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  : > "$file"
}

finalize_notes() {
  local channel="${1:?channel (nightly|beta|stable)}"
  case "$channel" in
    nightly)
      prepend_current_to_beta
      ;;
    beta)
      clear_file "${BETA_CHANGES_FILE:-Changes/Beta.md}"
      echo "✓ Cleared ${BETA_CHANGES_FILE:-Changes/Beta.md} after beta consumption."
      ;;
    stable)
      clear_file "${CURRENT_CHANGES_FILE:-Changes/Current.md}"
      echo "✓ Cleared ${CURRENT_CHANGES_FILE:-Changes/Current.md} after stable consumption."
      ;;
    *)
      fail "Unknown finalize channel '$channel' (expected nightly, beta, or stable)"
      ;;
  esac
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

case "$command" in
  body)
    compose_body "$@"
    ;;
  html)
    write_html "$@"
    ;;
  delta)
    emit_delta "$@"
    ;;
  collect)
    collect_files "$@"
    ;;
  finalize)
    finalize_notes "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
