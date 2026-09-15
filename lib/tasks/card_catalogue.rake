require "csv"

namespace :cards do
  namespace :catalogue do
    desc "Import real-card research (does not publish cards)"
    task import: :environment do
      result = CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
      puts "Added #{result[:added]} candidates; preserved #{result[:preserved]} existing candidates."
      puts "Review totals: #{CardCandidate.group(:country, :review_status).count.inspect}"
    end

    desc "Export research and remaining gaps from the local candidate database"
    task export: :environment do
      directory = Rails.root.join("data/real_cards/review")
      FileUtils.mkdir_p(directory)
      rows = []
      gaps = []
      lines = [ "# Real-card catalogue", "", "Generated from card_candidates. This research is separate from the live app and has not been deployed. Research status describes source coverage; review status records human review only.", "", "Amounts use the stated currency. Unknown is not zero. Points and miles are not cash values. Offers may vary by application channel. Perks and eligibility are selected summaries, not exhaustive terms.", "" ]
      CardCandidate.in_shortlist_order.each do |card|
        r = card.research
        fees = r.fetch("fees", {})
        rewards = r.fetch("rewards", []).map do |rule|
          extras = rule.slice("effective_on", "effective_until", "earning_basis").map { |key, value| "#{key}: #{value}" }
          ([ "#{rule['rate']} #{rule['unit']} — #{rule['category']}", rule["conditions"] ] + extras).compact_blank.join("; ")
        end.join(" | ")
        rewards = "No ongoing rewards" if rewards.empty? && r["rewards_status"] == "none"
        rewards = "No ongoing rewards advertised on retrieved page" if rewards.empty? && r["rewards_status"] == "not_advertised"
        annual = fees["annual"] || ("N/A — monthly billing" if fees["annual_applicability"] == "monthly_billing")
        monthly = fees["monthly"] || ("N/A — not separately billed" if fees["monthly_applicability"] == "not_separately_billed")
        intro = fees["intro"] || ("No fee waiver listed" if fees["intro_status"] == "no_waiver_listed")
        welcome = r["welcome_offer"]
        welcome ||= "No welcome offer" if r["welcome_offer_status"] == "none"
        welcome ||= "No welcome offer advertised in retrieved page" if r["welcome_offer_status"] == "not_advertised_in_retrieved_page"
        guidance = r["editorial_credit_guidance"]
        row = {
          number: card.shortlist_position, key: card.source_key, country: card.country, currency: card.currency,
          name: card.name, issuer: r["issuer"], review_status: card.review_status, research_status: r["research_status"],
          annual_fee: annual, monthly_fee: monthly, intro_fee: intro, foreign_purchase_fee_percent: fees["foreign_purchase_percent"],
          fee_conditions: [ fees["annual_conditions"], fees["foreign_purchase_conditions"] ].compact.join(" | "),
          rewards: rewards.presence, rewards_scope: r["rewards_scope"], welcome_offer: welcome, welcome_offer_status: r["welcome_offer_status"],
          perks: r.fetch("perks", []).join(" | ").presence || "No additional perks captured", network: r["network"],
          interest: r.fetch("interest", {}).compact.map { |key, value| "#{key}: #{value}" }.join(" | ").presence,
          eligibility: r["eligibility"], credit_guidance: guidance && "#{guidance['band']} — editorial guidance, not an approval requirement",
          quiz_tags: r["quiz_tags"].join(" | "), conditions: r["recommendation_conditions"].join(" | "),
          scheduled_changes: r.fetch("scheduled_changes", []).map(&:to_json).join(" | "),
          missing_or_uncertain: r["review_flags"].join(" | "), primary_source: r["primary_source_url"],
          sources: r["sources"].map { |s| "#{s['url']} (#{s['evidence']}; checked #{s['checked_on']})" }.join(" | "),
          reviewer_notes: card.review_notes.presence || "No human review recorded"
        }
        rows << row
        lines += [ "## #{card.shortlist_position}. #{card.name} (#{card.country})", "", "Key: `#{card.source_key}`", "" ]
        row.except(:number, :key, :name, :sources).each do |key, value|
          lines << "- #{key.to_s.humanize}: #{value.presence || 'Not captured'}"
        end
        lines += [ "", "Sources:", "" ]
        r["sources"].each { |s| lines << "- [#{s['label']}](#{s['url']}) — #{s['evidence']}; checked #{s['checked_on']}" }
        lines << ""
        missing = []
        missing << [ "Account fee", "Annual and monthly account fees not captured" ] if fees["annual"].nil? && fees["monthly"].nil?
        missing << [ "Foreign purchase fee", "Exact product fee not captured" ] if fees["foreign_purchase_percent"].nil?
        missing << [ "Rewards", "Core schedule unresolved" ] if rewards.blank?
        missing << [ "Welcome offer", "Amount not exposed in retrieved page" ] if welcome.nil?
        missing << [ "Network (optional)", "Not captured" ] if r["network"].nil?
        missing << [ "Perks (optional)", "No additional benefits captured" ] if r.fetch("perks", []).empty?
        missing << [ "Eligibility (partial)", "No application criteria captured" ] if r["eligibility"].blank?
        missing << [ "Interest (optional for rewards demo)", "No numerical purchase or representative APR captured" ] unless r.fetch("interest", {}).slice("purchase_apr", "representative_apr").values.any? { |v| v.to_s.match?(/\d/) }
        r["review_flags"].each { |flag| missing << [ "Source caveat", flag ] }
        missing.each { |field, detail| gaps << { key: card.source_key, name: card.name, field: field, detail: detail, source: r["primary_source_url"] || r["sources"].first["url"] } }
      end
      { "cards.csv" => rows, "unknowns.csv" => gaps }.each do |filename, records|
        headers = records.first&.keys || []
        CSV.open(directory.join(filename), "wb", write_headers: true, headers: headers) do |csv|
          records.each do |record|
            # Prevent formula execution when research is opened in a spreadsheet.
            csv << record.values.map { |value| (value.nil? ? "Not captured" : value.to_s).sub(/\A(?=[=+@\-\t\r])/, "'") }
          end
        end
      end
      File.write(directory.join("cards.md"), lines.join("\n").rstrip + "\n")
      gap_lines = [ "# Remaining research gaps", "", "Generated with cards:catalogue:export. These are source gaps, not a request to manually research every card. Optional fields do not block a rewards demo. M&S Shopping Plus is on hold; Halifax account pricing is unresolved. See cards.md for captured facts and source caveats.", "", "No numerical issuer approval cutoff is inferred for any card. Eligibility is partial throughout. Perks are selected rather than exhaustive. A blank secondary billing field, no advertised bonus, or personalised offer is not automatically missing data.", "" ]
      gaps.group_by { |gap| gap[:key] }.each do |key, items|
        gap_lines += [ "## #{items.first[:name]}", "", "Key: `#{key}`", "" ]
        items.each { |gap| gap_lines << "- **#{gap[:field]}:** #{gap[:detail]}" }
        gap_lines += [ "", "[Primary source](#{items.first[:source]})", "" ]
      end
      File.write(directory.join("unknowns.md"), gap_lines.join("\n").rstrip + "\n")
      puts "Exported #{rows.length} candidates and #{gaps.length} remaining field gaps/caveats to #{directory}"
    end
  end
end
