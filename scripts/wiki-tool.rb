#!/usr/bin/env ruby
# Internal helper for wiki marker validation, rendering, promotion, and PR summaries.

require "fileutils"
require "open3"
require "optparse"
require "shellwords"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
DEFAULT_SOURCE = "docs/wiki"
CHANNEL_RANK = { "stable" => 0, "beta" => 1, "nightly" => 2 }.freeze
STICKY_MARKER = "<!-- contained-wiki-pr -->"

class WikiError < StandardError; end

Block = Struct.new(:kind, :attrs, :file, :start_line, :end_line, :body_lines, keyword_init: true) do
  def id
    attrs["id"]
  end

  def channel
    attrs["channel"]
  end

  def since
    attrs["since"]
  end
end

class WikiDoc
  attr_reader :source, :files, :blocks, :errors

  def initialize(source)
    @source = File.expand_path(source, ROOT)
    @files = Dir.glob(File.join(@source, "*.md")).sort
    @blocks = []
    @errors = []
  end

  def parse
    files.each { |file| parse_file(file) }
    validate_blocks
    validate_links
    self
  end

  def relative_path(path)
    PathnameSafe.relative_path(path, source)
  end

  private

  def parse_file(file)
    lines = File.readlines(file, chomp: true)
    open_block = nil
    open_body = []

    lines.each_with_index do |line, index|
      line_number = index + 1
      if (match = line.match(/\A\s*<!--\s*wiki:(section|variant)\s+(.+?)\s*-->\s*\z/))
        if open_block
          errors << "#{relative_path(file)}:#{line_number}: nested wiki block inside #{open_block.kind} '#{open_block.id}'"
          next
        end

        attrs = parse_attrs(match[2], file, line_number)
        open_block = Block.new(
          kind: match[1],
          attrs: attrs,
          file: file,
          start_line: line_number,
          body_lines: []
        )
        open_body = []
      elsif (match = line.match(/\A\s*<!--\s*\/wiki:(section|variant)\s*-->\s*\z/))
        unless open_block
          errors << "#{relative_path(file)}:#{line_number}: closing wiki #{match[1]} without an opening marker"
          next
        end
        if open_block.kind != match[1]
          errors << "#{relative_path(file)}:#{line_number}: closing wiki #{match[1]} does not match open #{open_block.kind}"
          next
        end

        open_block.end_line = line_number
        open_block.body_lines = open_body
        blocks << open_block
        open_block = nil
        open_body = []
      elsif open_block
        open_body << line
      end
    end

    if open_block
      errors << "#{relative_path(file)}:#{open_block.start_line}: wiki #{open_block.kind} '#{open_block.id}' is missing a closing marker"
    end
  end

  def parse_attrs(raw, file, line_number)
    attrs = {}
    scanner = raw.dup

    until scanner.strip.empty?
      scanner = scanner.lstrip
      match = scanner.match(/\A([a-zA-Z_][a-zA-Z0-9_-]*)="([^"]*)"/)
      unless match
        errors << "#{relative_path(file)}:#{line_number}: malformed wiki marker attributes"
        break
      end

      key = match[1]
      value = match[2]
      if attrs.key?(key)
        errors << "#{relative_path(file)}:#{line_number}: duplicate wiki marker attribute '#{key}'"
      end
      attrs[key] = value
      scanner = scanner[match[0].length..] || ""
    end

    attrs
  end

  def validate_blocks
    sections_by_id = {}
    variants_by_key = {}

    blocks.each do |block|
      if block.id.to_s.empty?
        errors << "#{relative_path(block.file)}:#{block.start_line}: wiki #{block.kind} is missing id"
      end

      case block.kind
      when "section"
        if sections_by_id.key?(block.id)
          other = sections_by_id.fetch(block.id)
          errors << "#{relative_path(block.file)}:#{block.start_line}: duplicate wiki section id '#{block.id}' already declared at #{relative_path(other.file)}:#{other.start_line}"
        else
          sections_by_id[block.id] = block
        end
      when "variant"
        unless %w[beta nightly].include?(block.channel)
          errors << "#{relative_path(block.file)}:#{block.start_line}: wiki variant '#{block.id}' must use channel beta or nightly"
        end
        if block.since.to_s.empty?
          errors << "#{relative_path(block.file)}:#{block.start_line}: wiki variant '#{block.id}' is missing since"
        end

        key = [block.id, block.channel]
        if variants_by_key.key?(key)
          other = variants_by_key.fetch(key)
          errors << "#{relative_path(block.file)}:#{block.start_line}: duplicate #{block.channel} wiki variant '#{block.id}' already declared at #{relative_path(other.file)}:#{other.start_line}"
        else
          variants_by_key[key] = block
        end

        label = "[#{block.channel.capitalize}]"
        first_content = block.body_lines.find { |body_line| !body_line.strip.empty? }.to_s
        unless first_content.include?(label)
          errors << "#{relative_path(block.file)}:#{block.start_line}: wiki variant '#{block.id}' should start with a visible #{label} label"
        end
      end
    end

    blocks.select { |block| block.kind == "variant" }.each do |variant|
      section = sections_by_id[variant.id]
      if section.nil?
        errors << "#{relative_path(variant.file)}:#{variant.start_line}: wiki variant '#{variant.id}' has no matching wiki section"
      elsif section.file != variant.file
        errors << "#{relative_path(variant.file)}:#{variant.start_line}: wiki variant '#{variant.id}' must live in the same file as its section"
      elsif section.start_line > variant.start_line
        errors << "#{relative_path(variant.file)}:#{variant.start_line}: wiki variant '#{variant.id}' must appear below its stable section"
      end
    end
  end

  def validate_links
    page_names = files.map { |file| File.basename(file, ".md") }.to_set
    files.each do |file|
      File.readlines(file, chomp: true).each_with_index do |line, index|
        line.scan(/\[\[([^\]]+)\]\]/).flatten.each do |raw_target|
          target = raw_target.split("|", 2).last.to_s.split("#", 2).first.to_s.strip
          next if target.empty?

          candidates = [target, target.tr(" ", "-")]
          next if candidates.any? { |candidate| page_names.include?(candidate) }

          errors << "#{relative_path(file)}:#{index + 1}: broken wiki link [[#{raw_target}]]"
        end
      end
    end
  end
end

module PathnameSafe
  module_function

  def relative_path(path, base)
    path = File.expand_path(path)
    base = File.expand_path(base)
    path.sub(/\A#{Regexp.escape(base)}\/?/, "")
  end
end

def require_set
  require "set"
end

def fail_with(errors)
  errors.each { |error| warn "x #{error}" }
  raise WikiError, "#{errors.length} wiki validation #{errors.length == 1 ? "error" : "errors"}"
end

def parse_doc!(source)
  require_set
  doc = WikiDoc.new(source).parse
  fail_with(doc.errors) unless doc.errors.empty?
  doc
end

def display_channel(channel)
  channel.capitalize
end

def included_variant?(variant, channel)
  CHANNEL_RANK.fetch(variant.channel) <= CHANNEL_RANK.fetch(channel)
end

def render_section(body_lines, variants)
  return body_lines if variants.empty?

  labels = variants.map { |variant| "[#{display_channel(variant.channel)}]" }.uniq
  since_values = variants.map(&:since).compact.reject(&:empty?).uniq
  since = since_values.length == 1 ? " in #{since_values.first}" : ""
  replacement_word = labels.length == 1 ? "replacement" : "replacements"
  label_text = labels.length == 1 ? labels.first : "#{labels[0..-2].join(", ")} and #{labels[-1]}"
  notice = [
    "",
    "> [!WARNING]",
    "> **Deprecating#{since}.** See the #{label_text} #{replacement_word} below.",
    ""
  ]

  output = []
  inserted = false
  body_lines.each do |line|
    output << line
    next if inserted

    if line.match?(/\A#{'#'}{1,6}\s+/)
      output.concat(notice)
      inserted = true
    end
  end

  output = notice + output unless inserted
  output
end

def render_file(path, doc, channel)
  lines = File.readlines(path, chomp: true)
  blocks = doc.blocks.select { |block| block.file == path }.sort_by(&:start_line)
  variants_by_id = blocks
    .select { |block| block.kind == "variant" && included_variant?(block, channel) }
    .group_by(&:id)

  output = []
  cursor = 1
  blocks.each do |block|
    next if block.start_line < cursor

    output.concat(lines[(cursor - 1)...(block.start_line - 1)] || [])

    case block.kind
    when "section"
      output.concat(render_section(block.body_lines, variants_by_id.fetch(block.id, [])))
    when "variant"
      output.concat(block.body_lines) if included_variant?(block, channel)
    end

    cursor = block.end_line + 1
  end
  output.concat(lines[(cursor - 1)..] || [])
  "#{output.join("\n")}\n"
end

def command_render(argv)
  options = { source: DEFAULT_SOURCE, output: nil, channel: "nightly" }
  parser = OptionParser.new do |opts|
    opts.on("--source PATH") { |value| options[:source] = value }
    opts.on("--output PATH") { |value| options[:output] = value }
    opts.on("--channel CHANNEL") { |value| options[:channel] = value }
  end
  parser.parse!(argv)

  raise WikiError, "--output is required" if options[:output].to_s.empty?
  raise WikiError, "unknown channel '#{options[:channel]}'" unless CHANNEL_RANK.key?(options[:channel])

  doc = parse_doc!(options[:source])
  output_dir = File.expand_path(options[:output], ROOT)
  FileUtils.rm_rf(output_dir)
  FileUtils.mkdir_p(output_dir)

  doc.files.each do |path|
    rendered = render_file(path, doc, options[:channel])
    File.write(File.join(output_dir, File.basename(path)), rendered)
  end

  puts "✓ Rendered wiki to #{PathnameSafe.relative_path(output_dir, ROOT)} (#{options[:channel]})"
end

def section_variant_ids(source)
  return { sections: Set.new, variants: Set.new } unless File.exist?(source)

  sections = Set.new
  variants = Set.new
  File.read(source).scan(/<!--\s*wiki:(section|variant)\s+(.+?)\s*-->/).each do |kind, raw_attrs|
    attrs = {}
    raw_attrs.scan(/([a-zA-Z_][a-zA-Z0-9_-]*)="([^"]*)"/).each { |key, value| attrs[key] = value }
    if kind == "section"
      sections << attrs["id"] if attrs["id"]
    else
      variants << "#{attrs["id"]}:#{attrs["channel"]}" if attrs["id"] && attrs["channel"]
    end
  end
  { sections: sections, variants: variants }
end

def git_changed_files(base_ref, head_ref)
  return [] if base_ref.to_s.empty?

  output, status = Open3.capture2("git", "diff", "--name-status", "#{base_ref}...#{head_ref}")
  raise WikiError, "git diff failed for #{base_ref}...#{head_ref}" unless status.success?

  output.lines.map do |line|
    status_code, path = line.chomp.split(/\s+/, 2)
    [status_code, path]
  end
end

def git_file(ref, path)
  output, status = Open3.capture2("git", "show", "#{ref}:#{path}")
  status.success? ? output : nil
end

def write_summary(path, lines)
  return if path.to_s.empty?

  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, "#{lines.join("\n")}\n")
end

def command_check(argv)
  options = {
    source: DEFAULT_SOURCE,
    base_ref: nil,
    head_ref: "HEAD",
    summary_file: nil,
    require_approval: false,
    approved: false
  }
  parser = OptionParser.new do |opts|
    opts.on("--source PATH") { |value| options[:source] = value }
    opts.on("--base-ref REF") { |value| options[:base_ref] = value }
    opts.on("--head-ref REF") { |value| options[:head_ref] = value }
    opts.on("--summary-file PATH") { |value| options[:summary_file] = value }
    opts.on("--require-approval") { options[:require_approval] = true }
    opts.on("--approved") { options[:approved] = true }
  end
  parser.parse!(argv)

  require_set
  errors = WikiDoc.new(options[:source]).parse.errors

  changed = git_changed_files(options[:base_ref], options[:head_ref])
  changed_paths = changed.map(&:last).compact
  changed_wiki = changed_paths.select { |path| path.start_with?("docs/wiki/") }
  source_like = changed_paths.select do |path|
    path.start_with?("Sources/", "Tests/", "scripts/", ".github/workflows/") ||
      %w[Package.swift Package.resolved README.md AGENTS.md].include?(path)
  end
  needs_advisory = changed_wiki.empty? && !source_like.empty?

  page_changes = changed_wiki.map { |path| path.delete_prefix("docs/wiki/") }.sort
  added_sections = Set.new
  removed_sections = Set.new
  added_variants = Set.new
  removed_variants = Set.new

  changed_wiki.each do |path|
    old_content = options[:base_ref] ? git_file(options[:base_ref], path) : nil
    new_content = File.exist?(path) ? File.read(path) : nil
    old_ids = section_variant_ids_from_content(old_content)
    new_ids = section_variant_ids_from_content(new_content)
    added_sections.merge(new_ids[:sections] - old_ids[:sections])
    removed_sections.merge(old_ids[:sections] - new_ids[:sections])
    added_variants.merge(new_ids[:variants] - old_ids[:variants])
    removed_variants.merge(old_ids[:variants] - new_ids[:variants])
  end

  approval_missing = options[:require_approval] && !changed_wiki.empty? && !options[:approved]
  errors << "wiki-approved label is required for docs/wiki changes" if approval_missing

  summary = []
  summary << STICKY_MARKER
  summary << "## Wiki Review"
  summary << ""
  if changed_wiki.empty?
    summary << "- Wiki pages changed: none"
  else
    summary << "- Wiki pages changed: #{page_changes.join(", ")}"
  end
  summary << "- Approval: #{changed_wiki.empty? ? "not required" : (options[:approved] ? "wiki-approved present" : "wiki-approved missing")}"
  summary << "- Source-only advisory: #{needs_advisory ? "review whether docs/wiki needs an update" : "not needed"}"
  summary << "- Added section ids: #{added_sections.empty? ? "none" : added_sections.to_a.sort.join(", ")}"
  summary << "- Removed section ids: #{removed_sections.empty? ? "none" : removed_sections.to_a.sort.join(", ")}"
  summary << "- Added variants: #{added_variants.empty? ? "none" : added_variants.to_a.sort.join(", ")}"
  summary << "- Removed variants: #{removed_variants.empty? ? "none" : removed_variants.to_a.sort.join(", ")}"
  summary << ""
  summary << "Rendered preview and diff are attached as the `wiki-preview` artifact when this workflow runs in GitHub Actions."
  summary << ""
  if errors.empty?
    summary << "Status: passed."
  else
    summary << "Status: failed."
    errors.each { |error| summary << "- #{error}" }
  end
  write_summary(options[:summary_file], summary)

  if errors.empty?
    puts "✓ Wiki check passed."
  else
    fail_with(errors)
  end
end

def section_variant_ids_from_content(content)
  return { sections: Set.new, variants: Set.new } if content.nil?

  sections = Set.new
  variants = Set.new
  content.scan(/<!--\s*wiki:(section|variant)\s+(.+?)\s*-->/).each do |kind, raw_attrs|
    attrs = {}
    raw_attrs.scan(/([a-zA-Z_][a-zA-Z0-9_-]*)="([^"]*)"/).each { |key, value| attrs[key] = value }
    if kind == "section"
      sections << attrs["id"] if attrs["id"]
    else
      variants << "#{attrs["id"]}:#{attrs["channel"]}" if attrs["id"] && attrs["channel"]
    end
  end
  { sections: sections, variants: variants }
end

def command_promote(argv)
  options = { source: DEFAULT_SOURCE, from: nil, to: nil }
  parser = OptionParser.new do |opts|
    opts.on("--source PATH") { |value| options[:source] = value }
    opts.on("--from CHANNEL") { |value| options[:from] = value }
    opts.on("--to CHANNEL") { |value| options[:to] = value }
  end
  parser.parse!(argv)

  unless [%w[nightly beta], %w[beta stable]].include?([options[:from], options[:to]])
    raise WikiError, "supported promotions are nightly -> beta and beta -> stable"
  end

  doc = parse_doc!(options[:source])
  changed_files = []

  doc.files.each do |path|
    blocks = doc.blocks.select { |block| block.file == path }.sort_by(&:start_line)
    next if blocks.empty?

    lines = File.readlines(path, chomp: true)
    next_lines = if options[:from] == "nightly"
      promote_nightly_to_beta(lines, blocks)
    else
      promote_beta_to_stable(lines, blocks)
    end

    next if next_lines == lines

    File.write(path, "#{next_lines.join("\n")}\n")
    changed_files << PathnameSafe.relative_path(path, ROOT)
  end

  if changed_files.empty?
    puts "No #{options[:from]} wiki variants were found to promote."
  else
    puts "✓ Promoted wiki variants in #{changed_files.join(", ")}"
  end
end

def promote_nightly_to_beta(lines, blocks)
  output = lines.dup
  blocks.select { |block| block.kind == "variant" && block.channel == "nightly" }.each do |block|
    output[block.start_line - 1] = output[block.start_line - 1].sub('channel="nightly"', 'channel="beta"')
    ((block.start_line)...(block.end_line - 1)).each do |line_index|
      next unless output[line_index].match?(/\A#{'#'}{1,6}\s+/)

      output[line_index] = output[line_index].sub("[Nightly]", "[Beta]")
      break
    end
  end
  output
end

def strip_channel_label(lines, channel)
  label = "[#{display_channel(channel)}]"
  lines.map do |line|
    line.match?(/\A#{'#'}{1,6}\s+/) ? line.sub(/\s*#{Regexp.escape(label)}\s*/, " ") : line
  end
end

def promote_beta_to_stable(lines, blocks)
  beta_variants = blocks.select { |block| block.kind == "variant" && block.channel == "beta" }.group_by(&:id)
  return lines if beta_variants.empty?

  output = []
  cursor = 1
  blocks.each do |block|
    next if block.start_line < cursor

    output.concat(lines[(cursor - 1)...(block.start_line - 1)] || [])

    if block.kind == "section" && beta_variants.key?(block.id)
      output << lines[block.start_line - 1]
      output.concat(strip_channel_label(beta_variants.fetch(block.id).first.body_lines, "beta"))
      output << lines[block.end_line - 1]
    elsif block.kind == "variant" && block.channel == "beta"
      # Drop promoted beta variants after replacing their stable section.
    else
      output.concat(lines[(block.start_line - 1)..(block.end_line - 1)] || [])
    end

    cursor = block.end_line + 1
  end
  output.concat(lines[(cursor - 1)..] || [])
  output
end

def usage!
  warn "Usage: scripts/wiki-tool.rb <check|render|promote> [options]"
  exit 2
end

begin
  command = ARGV.shift || usage!
  case command
  when "check" then command_check(ARGV)
  when "render" then command_render(ARGV)
  when "promote" then command_promote(ARGV)
  else usage!
  end
rescue WikiError => error
  warn "x #{error.message}"
  exit 1
end
