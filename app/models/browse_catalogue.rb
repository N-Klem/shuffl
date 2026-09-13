class BrowseCatalogue
  def payload
    source = JSON.parse(File.read(Rails.root.join("data/cards.json"))).index_by { |c| c["name"] }
    cards = Card.order(:id).map do |card|
      data = source[card.name] || {}
      { id: card.id.to_s, name: card.name, issuer: card.issuer,
        annualFee: card.annual_fee.to_i, cardNetwork: card.network,
        pointsCurrency: data["pointsCurrency"] || "Points",
        signUpBonus: data["signUpBonus"] || { amount: 0, spend: 0, months: 0 },
        rewards: data["rewards"] || {}, perks: data["perks"] || card.perks.to_s.split(","),
        categories: data["categories"] || [], foreignTransactionFee: card.foreign_transaction_fee }
    end
    stacks = Stack.includes(:cards).order(:id).map do |stack|
      { id: stack.id.to_s, name: stack.name, issuer: ERB::Util.html_escape(stack.category),
        intro: ERB::Util.html_escape(stack.description), categories: [stack.category.downcase],
        ids: stack.cards.map { |c| c.id.to_s } }
    end
    { cards: cards, stacks: stacks }
  end
end
