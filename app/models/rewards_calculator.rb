# An ongoing full-year scenario, not a prediction of an account's remaining caps.
# Only explicitly reviewed cashback schedules can enter this calculation.
class RewardsCalculator
  CATEGORIES = %w[dining travel groceries gas streaming other].freeze
  LABELS = ["Dining", "Travel (direct bookings)", "Eligible US supermarkets", "US gas stations", "Eligible streaming", "Other eligible purchases"].freeze
  INPUT_VERSION = 1
  PROFILES = JSON.parse(Rails.root.join("config/cashback_rules.json").read).freeze
  ASSUMPTIONS = "Repeat this monthly budget for a full year with unused annual caps. Pay in full and on time. Includes ongoing annual and monthly card fees; excludes interest, transaction charges, introductory offers, welcome bonuses and conditional credits. Portal, online-retail, drugstore, transit and entertainment bonuses are not modeled."
  INPUT_GUIDANCE = "Enter net eligible purchases after returns, once only. Supermarkets exclude superstores (including Walmart and Target), warehouse clubs, convenience stores and meal kits. Gas excludes stations at supermarkets, superstores and clubs; put transit in Other. Streaming must qualify with each selected issuer and be billed directly. Put purchases outside these bonus definitions in Other. Exclude fees, interest, cash advances, transfers, gift cards and cash equivalents."

  def self.valid_amounts?(amounts)
    amounts.is_a?(Array) && amounts.size == 6 && amounts.all? do |value|
      value.is_a?(Numeric) && value.finite? && value.between?(0, 1_000_000)
    end
  end

  def self.unavailable_reason(card)
    return "Historical or unpublished card; no supported calculation." unless card.real_catalogue? && card.catalogue_status == "published"
    if card.reward_rules.any? { |rule| rule["unit"] != "cashback_percent" }
      return "Points or miles need an explicit redemption value; no dollar estimate."
    end
    profile = PROFILES[card.source_key]
    return "Reward conditions, membership or category calendar are not supported yet." unless profile
    return "Recorded reward terms changed; calculation needs review." unless card.reward_rules == profile["reviewed_rewards"]
    nil
  end

  def self.ongoing_fee(card)
    return nil unless card.real_catalogue?
    fees = card.catalogue_terms.fetch("fees", {})
    annual = decimal(fees["annual"])
    monthly = fees["monthly_applicability"] == "not_separately_billed" ? 0.to_d : decimal(fees["monthly"])
    return nil unless annual && monthly
    annual + monthly * 12
  end

  def self.decimal(value)
    number = BigDecimal(value.to_s, exception: false)
    number if number&.finite? && number >= 0
  end

  def initialize(cards:, amounts:, confirmed: false)
    @cards = cards.uniq(&:id)
    @amounts = amounts
    @confirmed = confirmed == true
  end

  def call
    fees = @cards.map { |card| self.class.ongoing_fee(card) }
    supported = @cards.reject { |card| self.class.unavailable_reason(card) }
    result = { status: "confirmation_required", gross: nil, net: nil,
      fees: fees.all? ? fees.sum.to_f : nil,
      contributions: @cards.map { |card| { cardId: card.id, gross: nil, reason: self.class.unavailable_reason(card) } }, allocation: [],
      assumptions: ASSUMPTIONS }
    if supported.empty?
      result[:status] = "unavailable"
      return result
    end
    return result unless @confirmed && self.class.valid_amounts?(@amounts)

    result[:status] = supported.size == @cards.size ? "available" : "partial"

    earnings = supported.to_h { |card| [card.id, 0.to_d] }
    CATEGORIES.each_with_index do |category, index|
      remaining = @amounts[index].to_s.to_d * 12
      # Each supported cap belongs to one card/category. Shared or rotating caps
      # cannot be added here without a separate, explicitly modeled allocator.
      segments = supported.flat_map do |card|
        profile = PROFILES.fetch(card.source_key)
        base = card.reward_rules.fetch(profile.fetch("base_rule")).fetch("rate").to_d
        bonus = profile.fetch("categories")[category]
        rows = [{ card: card, rate: base, limit: remaining }]
        if bonus
          rate = card.reward_rules.fetch(bonus.fetch("rule")).fetch("rate").to_d
          rows.unshift(card: card, rate: rate, limit: bonus["annual_cap"]&.to_d || remaining)
        end
        rows
      end
      segments.sort_by { |segment| -segment[:rate] }.each do |segment|
        break if remaining.zero?
        allocated = [remaining, segment[:limit]].min
        next if allocated.zero?
        earned = allocated * segment[:rate] / 100
        earnings[segment[:card].id] += earned
        result[:allocation] << { category: LABELS[index], cardId: segment[:card].id,
          annualSpend: allocated.to_f, rate: segment[:rate].to_f, gross: earned.round(2).to_f }
        remaining -= allocated
      end
    end
    result[:contributions].each { |row| row[:gross] = earnings[row[:cardId]].round(2).to_f if earnings.key?(row[:cardId]) }
    result[:gross] = earnings.values.sum.round(2).to_f
    result[:net] = (earnings.values.sum - fees.sum).round(2).to_f if result[:status] == "available" && fees.all?
    result
  end
end
