require "csv"

namespace :cards do
  namespace :catalogue do
    desc "Import real-card research for review (does not publish cards)"
    task import: :environment do
      result = CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
      puts "Added #{result[:added]} candidates; preserved #{result[:preserved]} existing candidates."
      puts "Review totals: #{CardCandidate.group(:country, :review_status).count.inspect}"
    end

    desc "Export the database candidates to CSV and Markdown for manual review"
    task export: :environment do
      directory = Rails.root.join("data/real_cards/review")
      FileUtils.mkdir_p(directory)
      headers = %w[number key country currency name issuer status annual_fee monthly_fee intro_fee foreign_purchase_fee rewards welcome_offer eligibility conditions missing_or_uncertain sources reviewer_notes]
      lines = [ "# Real-card catalogue review", "", "Generated from the local card_candidates database. Research is pending human review; this is not the live card catalogue.", "", "Amounts use the stated currency. UNKNOWN is not zero. Rates are card earnings, not estimated cash value. Sources may be search extracts; check their evidence label. General eligibility is incomplete unless explicitly stated. Offers may vary by applicant or application channel.", "", "Use source_key when sending corrections. The JSON research file is the portable initial import; repeat imports preserve database edits.", "" ]
      CSV.open(directory.join("cards.csv"), "wb", write_headers: true, headers: headers) do |csv|
        CardCandidate.in_shortlist_order.each do |card|
          r = card.research
          fees = r.fetch("fees", {})
          rewards = r.fetch("rewards", []).map { |rule| "#{rule['rate']} #{rule['unit']} — #{rule['category']}; #{rule['conditions']}" }.join(" | ")
          sources = r.fetch("sources", []).map { |s| "#{s['url']} (#{s['evidence']}; checked #{s['checked_on']})" }.join(" | ")
          row = [ card.shortlist_position, card.source_key, card.country, card.currency, card.name, r["issuer"], card.review_status,
                 fees["annual"], fees["monthly"], fees["intro"], fees["foreign_purchase_percent"], rewards,
                 r["welcome_offer"], r["eligibility"], r["recommendation_conditions"].join(" | "), r["review_flags"].join(" | "), sources, card.review_notes ]
          # Avoid spreadsheet formula evaluation when future research is imported.
          csv << row.map { |value| value.nil? ? "UNKNOWN" : value.to_s.sub(/\A(?=[=+@\-\t\r])/, "'") }
          lines += [ "## #{card.shortlist_position}. #{card.name} (#{card.country})", "", "Key: `#{card.source_key}` · Status: #{card.review_status}", "",
                    "- Issuer: #{r['issuer']}", "- Currency: #{card.currency}",
                    "- Annual fee: #{fees['annual'] || 'UNKNOWN'}; monthly fee: #{fees['monthly'] || 'UNKNOWN'}; introductory fee: #{fees['intro'] || 'UNKNOWN'}",
                    "- Foreign purchase fee: #{fees['foreign_purchase_percent'] || 'UNKNOWN'}%",
                    "- Rewards: #{rewards.presence || 'UNKNOWN'}", "- Welcome offer: #{r['welcome_offer'] || 'UNKNOWN'}",
                    "- Eligibility: #{r['eligibility'] || 'UNKNOWN'}", "- Quiz tags (editorial): #{r['quiz_tags'].join(', ')}",
                    "- Recommendation conditions: #{r['recommendation_conditions'].join('; ').presence || 'Country and eligibility checks'}",
                    "- Review flags: #{r['review_flags'].join('; ')}", "- Reviewer notes: #{card.review_notes.presence || 'Not reviewed'}", "", "Sources:", "" ]
          r["sources"].each { |s| lines << "- [#{s['label']}](#{s['url']}) — #{s['evidence']}; checked #{s['checked_on']}" }
          lines << ""
        end
      end
      File.write(directory.join("cards.md"), lines.join("\n"))
      puts "Exported #{CardCandidate.count} candidates to #{directory}"
    end
  end
end
