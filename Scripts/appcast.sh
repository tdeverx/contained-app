#!/usr/bin/env bash
# Generate, promote, and validate Sparkle appcasts.
# Usage: ./Scripts/appcast.sh <generate|promote|validate> [...]
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
  ./Scripts/appcast.sh generate <path-to-sparkle-bin-dir> [updates-dir]
  ./Scripts/appcast.sh promote [--non-nightly-only] <promoted-appcast.xml> <nightly-appcast.xml>
  ./Scripts/appcast.sh validate [appcast.xml]
USAGE
}

generate_appcast() {
  local sparkle_bin="${1:?Pass the path to the Sparkle bin directory containing generate_appcast}"
  local updates_dir="${2:-updates}"
  local download_prefix="${DOWNLOAD_PREFIX:-https://github.com/tdeverx/contained-app/releases/download/}"

  [ -d "$updates_dir" ] || fail "Updates dir '$updates_dir' not found"

  local key_args=()
  [ -n "${ED_KEY_FILE:-}" ] && key_args=(--ed-key-file "$ED_KEY_FILE")

  echo "▸ Generating appcast for $updates_dir (download prefix: $download_prefix)..."
  ./Scripts/notes.sh html "$updates_dir"
  if [ "${#key_args[@]}" -gt 0 ]; then
    "$sparkle_bin/generate_appcast" "${key_args[@]}" --embed-release-notes --download-url-prefix "$download_prefix" "$updates_dir"
  else
    "$sparkle_bin/generate_appcast" --embed-release-notes --download-url-prefix "$download_prefix" "$updates_dir"
  fi

  cp "$updates_dir/appcast.xml" appcast.xml
  echo "✓ Wrote appcast.xml at the repo root for this branch."
}

promote_appcast() {
  local filter_mode="all"
  if [ "${1:-}" = "--non-nightly-only" ]; then
    filter_mode="non-nightly"
    shift
  fi

  local promoted="${1:?path to promoted appcast.xml}"
  local nightly="${2:?path to nightly appcast.xml}"

  [ -f "$promoted" ] || fail "Promoted appcast '$promoted' not found"

  if [ ! -f "$nightly" ]; then
    cat > "$nightly" <<'XML'
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Contained</title>
    </channel>
</rss>
XML
  fi

  PROMOTED_APPCAST="$promoted" FILTER_MODE="$filter_mode" perl -0pi -e '
      my $source_path = $ENV{"PROMOTED_APPCAST"};
      my $filter_mode = $ENV{"FILTER_MODE"} // "all";
      open my $source_fh, "<", $source_path or die "Unable to read $source_path: $!";
      local $/;
      my $source = <$source_fh>;
      close $source_fh;

      my @promoted_items;
      while ($source =~ m{(<item>.*?</item>)}gs) {
          my $item = $1;
          $item =~ m{<sparkle:version>([^<]+)</sparkle:version>}
              or die "No sparkle:version in promoted item\n";
          my $version = $1;
          my ($short_version) = $item =~ m{<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>};
          next if $filter_mode eq "non-nightly" && defined $short_version && $short_version =~ /-nightly\./;
          push @promoted_items, [$version, $item];
      }

      if (!@promoted_items) {
          next;
      }

      my $insert = "";
      for my $entry (@promoted_items) {
          my ($version, $item) = @$entry;
          my $quoted_version = quotemeta($version);
          s{\s*<item>.*?<sparkle:version>$quoted_version</sparkle:version>.*?</item>}{}gs;
          $insert .= "\n        $item\n";
      }

      s{(</title>\s*)}{$1$insert}s
          or die "No channel title found in nightly appcast\n";
  ' "$nightly"

  echo "✓ Merged promoted appcast item(s) into $nightly"
}

validate_appcast() {
  local appcast="${1:-appcast.xml}"
  local channel="${CHANNEL:-nightly}"

  [ -f "$appcast" ] || fail "Appcast '$appcast' was not found"

  APPCAST="$appcast" CHANNEL_VALUE="$channel" ruby <<'RUBY'
require "rexml/document"
require "rexml/xpath"

path = ENV.fetch("APPCAST")
channel = ENV.fetch("CHANNEL_VALUE")
allow_missing_notes = ENV["ALLOW_MISSING_RELEASE_NOTES"] == "1"
namespaces = { "sparkle" => "http://www.andymatuschak.org/xml-namespaces/sparkle" }

def fail!(message)
  warn "✗ #{message}"
  exit 1
end

unless %w[stable beta nightly].include?(channel)
  fail!("Unknown CHANNEL '#{channel}' (expected stable, beta, or nightly)")
end

doc = REXML::Document.new(File.read(path))
items = REXML::XPath.match(doc, "//item")
fail!("Appcast has no <item> entries") if items.empty?

items.each_with_index do |item, index|
  label = "item #{index + 1}"
  version = REXML::XPath.first(item, "sparkle:version", namespaces)&.text.to_s.strip
  short_version = REXML::XPath.first(item, "sparkle:shortVersionString", namespaces)&.text.to_s.strip
  enclosure = REXML::XPath.first(item, "enclosure")
  enclosure_url = enclosure&.attributes&.[]("url").to_s.strip
  description = REXML::XPath.first(item, "description")&.text.to_s.strip
  release_notes_link = REXML::XPath.first(item, "sparkle:releaseNotesLink", namespaces)&.text.to_s.strip

  fail!("#{label} is missing sparkle:version") if version.empty?
  fail!("#{label} sparkle:version must be numeric, got '#{version}'") unless version.match?(/\A[1-9][0-9]*\z/)
  fail!("#{label} is missing sparkle:shortVersionString") if short_version.empty?
  fail!("#{label} is missing enclosure URL") if enclosure_url.empty?

  unless allow_missing_notes || !description.empty? || !release_notes_link.empty?
    fail!("#{label} is missing embedded or linked release notes")
  end

  case channel
  when "stable"
    fail!("#{label} is not a stable short version: #{short_version}") if short_version.match?(/-(beta|nightly)\./)
  when "beta"
    fail!("#{label} is not a beta short version: #{short_version}") unless short_version.include?("-beta.")
  when "nightly"
    # Nightly intentionally accepts stable, beta, and nightly items.
  end
end

puts "✓ Appcast validation passed for #{path} (#{channel}, #{items.length} item#{items.length == 1 ? "" : "s"})."
RUBY
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift

case "$command" in
  generate)
    generate_appcast "$@"
    ;;
  promote)
    promote_appcast "$@"
    ;;
  validate)
    validate_appcast "$@"
    ;;
  *)
    usage
    exit 2
    ;;
esac
