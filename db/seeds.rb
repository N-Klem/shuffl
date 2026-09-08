# frozen_string_literal: true

require "json"

puts "Seeding cards..."

# Load the JSON card data
cards_path = Rails.root.join("data", "cards.json")
cards_data = JSON.parse(File.read(cards_path))

cards_data.each do |card|
  # Map JSON fields to DB columns
  max_reward = card["rewards"].values.max
  top_category = card["rewards"].max_by { |_, v| v }.first

  bonus = card["signUpBonus"]
  welcome_bonus = if bonus && bonus["amount"].to_i > 0
    "#{bonus['amount'].to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} #{card['pointsCurrency']} after spending $#{bonus['spend'].to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} in #{bonus['months']} months"
  else
    "None"
  end

  description = "The #{card['name']} from #{card['issuer']} offers up to #{max_reward}x on #{top_category}. " \
                "#{card['annualFee'].to_i.zero? ? 'No annual fee.' : "Annual fee: $#{card['annualFee']}."} " \
                "#{card['foreignTransactionFee'] ? 'Foreign transaction fee applies.' : 'No foreign transaction fee.'}"

  Card.find_or_create_by!(name: card["name"]) do |c|
    c.issuer        = card["issuer"]
    c.network       = card["cardNetwork"]
    c.card_type     = card["categories"]&.first&.capitalize || "Other"
    c.annual_fee    = card["annualFee"]
    c.reward_rate   = max_reward
    c.welcome_bonus = welcome_bonus
    c.perks         = card["perks"]&.join(", ")
    c.best_for      = card["categories"]&.map(&:capitalize)&.join(", ")
    c.description   = description
  end
end

puts "Seeded #{Card.count} cards."
