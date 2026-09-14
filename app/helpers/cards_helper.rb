module CardsHelper
  FINISHES = %w[finish-graphite finish-burgundy finish-bone finish-steel finish-silver].freeze

  # Gives each card a consistent finish so the same card always looks the same.
  # Keyed on the name rather than the id: cards within a stack often have ids
  # spaced evenly apart, which made every card in a stack land on one finish.
  def card_finish(card)
    FINISHES[Digest::MD5.hexdigest(card.name.to_s).to_i(16) % FINISHES.size]
  end

  # A short line for a card in a fan/tile: its first perk, or its headline rate.
  def card_benefit(card)
    card.perks.to_s.split(",").map(&:strip).find(&:present?) || "#{card.reward_rate}x rewards"
  end

  # DESIGN.md: the pence drop to muted so figures line up and read as one number.
  def figure_with_pence(amount)
    whole, pence = number_to_currency(amount).split(".")
    return whole.html_safe if pence.blank?

    safe_join([ whole, tag.span(".#{pence}", class: "pence") ])
  end
end
