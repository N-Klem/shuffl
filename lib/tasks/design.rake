# Enforces the binding rules in DESIGN.md.
#
# Two of those rules ("no raw hex outside the token block", "no stylesheet names
# a font family") are already broken in a lot of places. Failing on every one of
# them would just teach everyone to skip the check, so this ratchets instead:
# existing violations are recorded per file in .design-baseline.yml and the check
# fails only when a file goes ABOVE its recorded number. Debt can shrink, never grow.
#
#   rake design:check      # what the hook runs
#   rake design:baseline   # re-record after you have cleaned some up

require "yaml"

module DesignCheck
  SHEETS   = "app/assets/stylesheets/*.css".freeze
  BASELINE = ".design-baseline.yml".freeze

  # Rules with zero tolerance — these are settled and nothing may reintroduce them.
  BANNED = {
    "#7B1622" => "old burgundy; the canonical brand colour is #601020 via var(--burgundy)",
    "#681522" => "old burgundy; the canonical brand colour is #601020 via var(--burgundy)",
    "#63111B" => "old burgundy hover; use var(--burgundy-hover)",
    "Helvetica Now" => "unlicensed face, never shipped; the typeface is Geist via var(--font-sans)",
    "Inter Tight" => "no longer in the stack; the typeface is Geist via var(--font-sans)",
    "#A85410" => "retired amber; money-out figures are #A12A36 via var(--brick)"
  }.freeze

  HEX  = /#[0-9a-fA-F]{3,8}\b/.freeze
  FONT = /font(?:-family)?\s*:(?![^;}]*var\()[^;}]*["'][A-Za-z]/.freeze

  module_function

  def sheets = Dir[SHEETS].sort

  def counts
    sheets.to_h do |path|
      body = File.read(path)
      [File.basename(path), { "hex" => body.scan(HEX).size, "fonts" => body.scan(FONT).size }]
    end
  end

  def banned_hits
    sheets.flat_map do |path|
      body = File.read(path)
      BANNED.filter_map do |needle, why|
        next unless body.downcase.include?(needle.downcase)
        "#{File.basename(path)}: #{needle} — #{why}"
      end
    end
  end

  def baseline
    File.exist?(BASELINE) ? YAML.load_file(BASELINE) : {}
  end
end

namespace :design do
  desc "Check stylesheets against the binding rules in DESIGN.md"
  task :check do
    now  = DesignCheck.counts
    base = DesignCheck.baseline
    failures = []

    DesignCheck.banned_hits.each { |hit| failures << "BANNED  #{hit}" }

    now.each do |file, tally|
      allowed = base[file] || { "hex" => 0, "fonts" => 0 }
      %w[hex fonts].each do |kind|
        next if tally[kind] <= allowed[kind].to_i
        failures << "GREW    #{file}: #{kind} #{allowed[kind].to_i} -> #{tally[kind]}. " \
                    "Use a token from application.css's :root instead of a literal."
      end
    end

    total   = now.values.sum { |t| t["hex"] }
    allowed = base.values.sum { |t| t["hex"].to_i }

    if failures.empty?
      puts "design:check OK — #{total} raw hex tracked as debt (ceiling #{allowed}), no banned values."
      puts "Cleaned some up? Run `rake design:baseline` to lock in the lower number."
    else
      puts "design:check FAILED", ""
      failures.each { |f| puts "  #{f}" }
      puts "", "See DESIGN.md. If a violation is genuinely unavoidable, say so in the PR and",
              "run `rake design:baseline` deliberately — do not edit the baseline by hand."
      abort
    end
  end

  desc "Re-record the current violation counts as the new ceiling"
  task :baseline do
    File.write(DesignCheck::BASELINE, DesignCheck.counts.to_yaml)
    total = DesignCheck.counts.values.sum { |t| t["hex"] }
    puts "Wrote #{DesignCheck::BASELINE} — ceiling is now #{total} raw hex."
  end
end
