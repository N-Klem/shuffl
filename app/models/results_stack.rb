require "json"

# Uses the same illustrative catalogue that seeds the app.
class ResultsStack
  CATEGORIES = %w[dining travel groceries gas streaming other].freeze
  LABELS = ["Dining", "Travel", "Groceries", "Gas & transport", "Streaming", "Everything else"].freeze

  def initialize(quiz_response)
    @quiz_response = quiz_response
  end

  def payload
    answers = JSON.parse(@quiz_response.answers.presence || "{}")
    ids = JSON.parse(@quiz_response.top_card_ids.presence || "[]")
    ranked = Card.ranked_for(answers)
    cards = (ids.filter_map { |id| ranked.find { |card| card.id == id } } + ranked).uniq
    source = JSON.parse(File.read(Rails.root.join("data/cards.json"))).index_by { |card| card["name"] }
    monthly = { "Under $500" => 300, "$500–$1,000" => 750, "$1,000–$2,500" => 1750,
                "$2,500–$5,000" => 3750, "$5,000+" => 6000 }.fetch(answers["monthly_card_spend"], 2500)
    amounts = [0.25, 0.15, 0.25, 0.1, 0.05].map { |share| (monthly * share).round }
    amounts << monthly - amounts.sum
    {
      cards: cards.map.with_index do |card, i|
        data = source[card.name]
        {
          id: card.id, name: card.name, role: card.best_for.presence || card.issuer,
          finish: %w[#e7e3da #701d2b #444748 #c7c8c5 #777c80][i % 5],
          ink: i % 5 == 0 || i % 5 == 3 ? "#242424" : "#fff",
          fee: card.annual_fee.to_f, perks: card.perks.to_s.split(",").map(&:strip).first(3),
          rates: CATEGORIES.map { |category| data&.dig("rewards", category).to_f },
          use: card.description.presence || "Compare this card’s rewards and fees with your spending.",
          url: Rails.application.routes.url_helpers.card_path(card)
        }
      end,
      selected: ids.filter_map { |id| cards.index { |card| card.id == id } },
      amounts: amounts,
      categories: LABELS
    }
  end
end
