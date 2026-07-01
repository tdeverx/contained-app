#!/usr/bin/env bash
# Validate Sparkle appcast structure and channel/build invariants.
set -euo pipefail

appcast="${1:-appcast.xml}"
channel="${CHANNEL:-nightly}"

[ -f "$appcast" ] || { echo "✗ Appcast '$appcast' was not found" >&2; exit 1; }

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
    if short_version.match?(/-(beta|nightly)\./)
      fail!("#{label} is not a stable short version: #{short_version}")
    end
  when "beta"
    unless short_version.include?("-beta.")
      fail!("#{label} is not a beta short version: #{short_version}")
    end
  when "nightly"
    # The nightly appcast is intentionally a superset of nightly, beta, and stable items.
  end
end

puts "✓ Appcast validation passed for #{path} (#{channel}, #{items.length} item#{items.length == 1 ? "" : "s"})."
RUBY
