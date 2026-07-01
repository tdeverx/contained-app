#!/usr/bin/env bash
# Emit channel/build changes since the previous appcast item for the same channel.
set -euo pipefail

cd "$(dirname "$0")/.."

channel="${CHANNEL:-${1:-nightly}}"
head_ref="${HEAD_REF:-${2:-HEAD}}"
appcast="${APPCAST:-appcast.xml}"
changelog="${CHANGELOG:-CHANGELOG.md}"

[ -f "$appcast" ] || exit 0

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

range="$previous_ref..$head_ref"
mkdir -p .release
tmp="$(mktemp -d .release/changes-since-release.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

normalize_markdown() {
  ruby -e '
lines = STDIN.read.lines.map(&:rstrip)
output = []

lines.each do |line|
  next if line.strip.empty?
  next if line == "# Changelog"
  next if line.match?(/\A##\s+\[?Unreleased\]?/)

  if line.match?(/\A\s+/) && output.last&.start_with?("- ")
    output[-1] = "#{output[-1]} #{line.strip}"
  else
    output << line
  end
end

puts output.join("\n")
'
}

for candidate in "changes/$channel" "changes/unreleased"; do
  if [ -d "$candidate" ]; then
    ./scripts/collect-changes.sh "$range" "$candidate" >> "$tmp/fragments.md"
  fi
done

if [ -s "$tmp/fragments.md" ]; then
  normalize_markdown < "$tmp/fragments.md"
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
  | normalize_markdown > "$tmp/delta.md" || :

if [ -s "$tmp/delta.md" ]; then
  cat "$tmp/delta.md"
else
  echo "- No channel-specific changes were recorded for this build."
fi
