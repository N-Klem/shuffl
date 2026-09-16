# Allocate purchases within a chosen reward programme. Unlike currencies are never
# ranked against each other, converted to dollars, or earned on the same purchase.
class SpendingPlan
  POINTS = JSON.parse(Rails.root.join("config/points_rules.json").read).freeze
  CASHBACK = { "programme" => "cashback", "label" => "Cashback", "unit" => "cashback" }.freeze
  ASSUMPTIONS = "Full-year scenario repeating your confirmed monthly budget, with unused annual caps and full, on-time repayment. Each purchase earns on one card only. Fees are shown separately; welcome offers, anniversary bonuses, conditional credits, transfers and temporary promotions are excluded. Portal and merchant-specific bonuses need separate purchase details and are not included. Points and miles have no assumed dollar value."

  def self.profile(card)
    return unless card.real_catalogue? && card.catalogue_status == "published"
    profile = POINTS[card.source_key] || RewardsCalculator::PROFILES[card.source_key]&.merge(CASHBACK)
    profile if profile && card.reward_rules == profile["reviewed_rewards"]
  end

  def self.valid_choices?(choices)
    choices.is_a?(Array) && choices.size == 6 && choices.all? { |choice| choice.is_a?(String) && choice.length <= 40 }
  end

  def initialize(cards:, amounts:, confirmed: false, programmes: [])
    @cards = cards.uniq(&:id)
    @amounts = amounts
    @confirmed = confirmed == true && RewardsCalculator.valid_amounts?(amounts)
    @programmes = programmes
    @supported = @cards.filter_map do |card|
      profile = self.class.profile(card)
      [card, profile] if profile
    end
  end

  def call
    groups = @supported.group_by { |_, profile| profile["programme"] }
    fees = @cards.map { |card| RewardsCalculator.ongoing_fee(card) }
    result = { status: "confirmation_required", categories: [], totals: [], allocation: [],
      fees: fees.all? ? fees.sum.to_f : nil, netCashback: nil,
      coveredCardIds: @supported.map { |card, _| card.id }, assumptions: ASSUMPTIONS }
    RewardsCalculator::CATEGORIES.each_with_index do |category, index|
      options = groups.map do |key, entries|
        segments = segments_for(entries, category)
        profile = entries.first.last
        { programme: key, label: profile["label"], unit: profile["unit"], cards: segments.uniq { |s| s[:cardId] },
          rate: segments.first[:rate] }
      end
      choice = @programmes[index].presence || (options.one? ? options.first[:programme] : nil)
      option = options.find { |entry| entry[:programme] == choice }
      row = { key: category, label: RewardsCalculator::LABELS[index], options: options,
        programme: option&.dig(:programme), monthlySpend: @confirmed ? @amounts[index] : nil, allocation: [] }
      if @confirmed && option
        remaining = @amounts[index].to_s.to_d * 12
        segments_for(groups.fetch(choice), category).each do |segment|
          break if remaining.zero?
          spend = [remaining, segment[:cap]&.to_d || remaining].min
          next if spend.zero?
          earned = spend * segment[:rate].to_d / (option[:unit] == "cashback" ? 100 : 1)
          row[:allocation] << segment.merge(annualSpend: spend.to_f, earned: earned.to_f,
            programme: choice, label: option[:label], unit: option[:unit], category: row[:label])
          remaining -= spend
        end
      end
      result[:categories] << row
    end
    return result if !@confirmed || groups.empty?
    if result[:categories].any? { |row| row[:monthlySpend].positive? && row[:programme].nil? }
      result[:status] = "choices_required"
      # No headline totals from a partially chosen spending plan.
      return result
    end
    result[:status] = "ready"
    result[:allocation] = result[:categories].flat_map { |row| row[:allocation] }
    result[:totals] = result[:allocation].group_by { |row| row[:programme] }.map do |key, rows|
      { programme: key, label: rows.first[:label], unit: rows.first[:unit],
        earned: rows.sum { |row| row[:earned].to_s.to_d }.round(2).to_f }
    end
    if result[:totals].empty? && groups.one?
      profile = @supported.first.last
      result[:totals] << { programme: profile["programme"], label: profile["label"], unit: profile["unit"], earned: 0.0 }
    end
    if result[:totals].one? && result[:totals].first[:unit] == "cashback" && fees.all?
      result[:netCashback] = (result[:totals].first[:earned].to_d - fees.sum).round(2).to_f
    end
    result
  end

  private

  def segments_for(entries, category)
    entries.flat_map do |card, profile|
      base = card.reward_rules.fetch(profile.fetch("base_rule"))
      note = profile.fetch("notes", {})[category]
      rows = [{ cardId: card.id, name: card.name, rate: base.fetch("rate").to_f, cap: nil,
        reason: note || "Everyday earning rate for eligible purchases in this category.", conditions: base["conditions"] }]
      if (bonus = profile.fetch("categories")[category])
        rule = card.reward_rules.fetch(bonus.fetch("rule"))
        rows.unshift(cardId: card.id, name: card.name, rate: rule.fetch("rate").to_f,
          cap: bonus["annual_cap"], reason: "This category qualifies for the card’s higher earning rate.", conditions: profile.fetch("category_conditions", {}).fetch(category, rule["conditions"]))
      end
      rows
    end.sort_by { |segment| -segment[:rate] }
  end
end
