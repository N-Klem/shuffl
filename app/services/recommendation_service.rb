class RecommendationService
  CREDIT_LIMITS = {
    "unknown" => 640, "fair" => 649, "good" => 719, "excellent" => 850
  }.freeze

  FEE_LIMITS = {
    "none" => 0, "low" => 99, "medium" => 249, "any" => Float::INFINITY
  }.freeze

  MONTHLY_SPEND = {
    "under_500" => 400, "500_1000" => 750, "1000_2000" => 1500,
    "2000_4000" => 3000, "over_4000" => 5000
  }.freeze

  NETWORK_MAP = {
    "visa" => %w[Visa Visa\ Signature Visa\ Infinite],
    "mastercard" => %w[Mastercard Mastercard\ World\ Elite],
    "amex" => %w[Amex]
  }.freeze

  LOYALTY_MAP = {
    "skyways" => "SkyWays", "avios" => "Avios", "world_hotels" => "World Hotels"
  }.freeze

  PERK_MAP = {
    "lounge" => ["Lounge access", "Airport lounge access", "Lounge visits", "Unlimited lounges"],
    "travel_insurance" => ["Travel insurance", "Travel cover", "Trip cover", "Trip insurance"],
    "phone_protection" => ["Phone cover", "Phone protection", "Device protection"],
    "purchase_protection" => ["Purchase protection", "Purchase cover", "Extended warranty"],
    "no_foreign_fee" => ["No foreign transaction fee", "No foreign fees", "No transaction fee"],
    "signup_bonus" => []  # handled separately via signUpBonus amount
  }.freeze

  def initialize(cards, answers)
    @cards = cards
    @answers = answers
  end

  def call
    pool = filter(@cards)

    # Fallback: relax filters progressively if pool is too small
    if pool.length < target_count
      pool = filter(@cards, relax: :network)
    end
    if pool.length < target_count
      pool = filter(@cards, relax: :all_soft)
    end
    if pool.length < target_count
      pool = @cards.select { |c| passes_credit?(c) && passes_fee?(c) }
    end

    pool.sort_by { |c| -score(c) }.first(target_count)
  end

  private

  def target_count
    case @answers[:card_count]
    when "1" then 1
    when "2_3" then 3
    else 3
    end
  end

  # ── Filtering ──────────────────────────────────────────────

  def filter(cards, relax: nil)
    cards.select do |c|
      passes_credit?(c) &&
        passes_fee?(c) &&
        (relax == :all_soft || passes_life_stage?(c)) &&
        ([:network, :all_soft].include?(relax) || passes_network?(c)) &&
        (relax == :all_soft || passes_foreign?(c))
    end
  end

  def passes_credit?(card)
    card["creditScoreMin"] <= CREDIT_LIMITS.fetch(@answers[:credit_band], 640)
  end

  def passes_fee?(card)
    card["annualFee"] <= FEE_LIMITS.fetch(@answers[:fee], 99)
  end

  def passes_life_stage?(card)
    if @answers[:life_stage] == "student"
      true  # students can get any card they qualify for; student cards get a score boost
    else
      !card["categories"].include?("student")  # non-students skip student-only cards
    end
  end

  def passes_network?(card)
    pref = @answers[:card_network]
    return true if pref.blank? || pref == "no_preference"
    NETWORK_MAP.fetch(pref, []).include?(card["cardNetwork"])
  end

  def passes_foreign?(card)
    return true unless @answers[:foreign_spending] == "regularly"
    !card["foreignTransactionFee"]
  end

  # ── Scoring ────────────────────────────────────────────────

  def score(card)
    total = 0.0

    # 1. Spending category match (top category worth more)
    top = @answers[:top_category]
    total += (card.dig("rewards", top).to_f * 5) if top.present?

    Array(@answers[:categories]).each do |cat|
      next if cat == top  # already counted above
      total += card.dig("rewards", cat).to_f * 2.5
    end

    # 2. Reward preference alignment
    pref = @answers[:preference]
    if pref == "cashback"
      total += 8 if card["categories"].include?("cashback")
      total += 4 if card["pointsCurrency"].to_s.downcase.include?("cash")
    elsif pref == "travel"
      total += 8 if card["categories"].include?("travel")
      total += card["transferPartners"].length * 1.2
    elsif pref == "points"
      total += 6 if card["transferPartners"].length > 2
      total += 4 if card["pointsCurrency"].present? && !card["pointsCurrency"].to_s.downcase.include?("cash")
    end

    # 3. Life stage bonus
    if @answers[:life_stage] == "student" && card["categories"].include?("student")
      total += 10
    end

    # 4. Goal alignment
    case @answers[:goal]
    when "build_credit"
      total += 8 if card["perks"].any? { |p| p.downcase.include?("credit") }
      total += 5 if card["annualFee"] == 0
    when "maximize_rewards"
      total += card.dig("rewards")&.values&.max.to_f * 2
    when "simplify"
      other_reward = card.dig("rewards", "other").to_f
      total += other_reward * 4  # flat-rate everywhere cards
      total += 5 if card["perks"].any? { |p| p.downcase.include?("everywhere") }
    when "specific_perk"
      # handled via perk matching below
    end

    # 5. Perk matching
    Array(@answers[:perks]).each do |perk|
      if perk == "signup_bonus"
        total += 4 if card.dig("signUpBonus", "amount").to_i > 0
      else
        keywords = PERK_MAP.fetch(perk, [])
        matches = card["perks"].count { |p| keywords.any? { |k| p.downcase.include?(k.downcase) } }
        total += matches * 3
      end
    end

    # 6. Sign-up bonus scoring
    bonus_amount = card.dig("signUpBonus", "amount").to_i
    bonus_spend = card.dig("signUpBonus", "spend").to_i
    monthly = MONTHLY_SPEND.fetch(@answers[:monthly_spend], 1500)
    bonus_months = card.dig("signUpBonus", "months").to_i

    case @answers[:signup_bonus]
    when "very"
      total += (bonus_amount / 5000.0).clamp(0, 8)
      # Extra points if they can actually hit the spend requirement
      total += 3 if bonus_spend > 0 && (monthly * bonus_months) >= bonus_spend
    when "nice"
      total += (bonus_amount / 10000.0).clamp(0, 4)
    end

    # 7. Foreign spending
    if @answers[:foreign_spending].in?(%w[regularly occasionally]) && !card["foreignTransactionFee"]
      total += (@answers[:foreign_spending] == "regularly" ? 6 : 3)
    end

    # 8. Loyalty program match
    loyalty = @answers[:loyalty_program]
    if loyalty.present? && loyalty != "no_preference"
      partner_name = LOYALTY_MAP[loyalty]
      if partner_name && card["transferPartners"].include?(partner_name)
        total += 10
      end
    end

    # 9. Network preference (soft boost on top of hard filter)
    if @answers[:card_network].present? && @answers[:card_network] != "no_preference"
      if NETWORK_MAP.fetch(@answers[:card_network], []).include?(card["cardNetwork"])
        total += 2
      end
    end

    # 10. Fee efficiency — penalise fees relative to monthly spend
    if card["annualFee"] > 0
      monthly = MONTHLY_SPEND.fetch(@answers[:monthly_spend], 1500)
      annual_spend = monthly * 12
      fee_ratio = card["annualFee"].to_f / annual_spend
      total -= fee_ratio * 30  # higher fee relative to spend = bigger penalty
    end

    # 11. Existing cards context
    if @answers[:existing_cards] == "none"
      total += 4 if card["annualFee"] == 0  # first card should be simple
      total += 3 if card["perks"].any? { |p| p.downcase.include?("credit") }
    end

    # 12. Authorized user boost
    if @answers[:authorized_user] == "interested"
      total += 3 if card["perks"].any? { |p| p.downcase.include?("family") }
    end

    total
  end
end
