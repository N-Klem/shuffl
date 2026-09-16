class BrowseCatalogue
  def payload
    cards = Card.available.order(:id).map do |card|
      { id: card.id.to_s, name: card.name, imageUrl: card.image_path, issuer: card.issuer,
        annualFee: card.annual_fee&.to_f, cardNetwork: card.network,
        rewards: {}, rewardSummary: card.reward_summary, rewardRules: card.reward_rules,
        welcomeOffer: card.displayed_welcome_offer, valueProfile: card.value_profile,
        perks: card.perk_list,
        categories: card.best_for.to_s.split(",").map { |category| category.strip.downcase },
        foreignTransactionFee: card.foreign_transaction_fee,
        url: Rails.application.routes.url_helpers.card_path(card) }
    end
    stacks = Stack.available.includes(:cards, :stack_cards).order(:id).map do |stack|
      { id: stack.id.to_s, name: stack.name, issuer: ERB::Util.html_escape(stack.category),
        intro: ERB::Util.html_escape(stack.description), categories: [stack.category.downcase],
        ids: stack.cards.map { |card| card.id.to_s }, notes: stack.notes,
        roles: stack.stack_cards.to_h { |member| [member.card_id.to_s, member.role] },
        url: Rails.application.routes.url_helpers.stack_path(stack) }
    end
    { cards: cards, stacks: stacks }
  end
end
