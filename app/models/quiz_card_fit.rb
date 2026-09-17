# Editorial fit scores, never dollar values or issuer approval predictions.
# Only captured, ongoing reward categories and benefits can supply coverage.
class QuizCardFit
  SPENDING_CHANNELS = {
    "Groceries" => %w[supermarket], "Dining out" => %w[dining],
    "Travel" => %w[direct_travel], "Gas & transport" => %w[gas transit],
    "Online shopping" => %w[online_retail],
    "Entertainment & subscriptions" => %w[streaming events], "Rent or bills" => %w[utilities phone]
  }.freeze
  FOLLOW_UP_CHANNELS = {
    "groceries_where" => { "Supermarkets" => %w[supermarket], "Walmart or Target" => %w[superstore],
      "Wholesale clubs" => %w[wholesale], "Online grocery orders" => %w[online_grocery], "A mix of places" => %w[supermarket superstore wholesale] },
    "shopping_where" => { "Amazon with Prime" => %w[amazon], "Amazon without Prime" => %w[amazon],
      "Other retailers" => %w[online_retail], "A mix of retailers" => %w[online_retail] },
    "dining_where" => { "Directly with restaurants or cafés" => %w[dining], "Delivery apps" => %w[delivery], "A mix of both" => %w[dining delivery] },
    "travel_booking" => { "Directly with airlines and hotels" => %w[direct_travel],
      "I’m comfortable using a card’s travel portal" => %w[direct_travel portal], "No preference" => %w[direct_travel] },
    "transport_spending" => { "Gas stations" => %w[gas], "EV charging" => %w[ev],
      "Public transport or rideshares" => %w[transit], "A mix" => %w[gas ev transit] },
    "entertainment_spending" => { "Streaming subscriptions" => %w[streaming], "Live events or cinemas" => %w[events], "A mix" => %w[streaming events] },
    "bills_spending" => { "Rent" => %w[rent], "Utilities" => %w[utilities], "Phone bills" => %w[phone],
      "Utilities or phone bills" => %w[utilities phone], "A mix" => %w[rent utilities phone] }
  }.freeze
  FOLLOW_UP_CATEGORIES = FOLLOW_UP_CHANNELS.keys.zip([
    "Groceries", "Online shopping", "Dining out", "Travel", "Gas & transport",
    "Entertainment & subscriptions", "Rent or bills"
  ]).to_h.freeze
  BENEFIT_PATTERNS = {
    "Airport lounge access" => /lounge|Sky Club/i,
    "Airline or hotel benefits" => /checked bag|bag free|hotel night|night certificate|free-night|Elite status|Diamond status|Discoverist/i,
    "Dining credits" => /dining credit|Uber Cash|Resy|Dunkin/i,
    "Shopping or subscription credits" => /digital-entertainment credit|Disney|Hulu|ESPN/i,
    "Purchase protection or insurance" => /protection|insurance|cover|damage waiver|warranty/i
  }.freeze

  attr_reader :card, :features, :reasons

  def initialize(card, answers)
    @card, @answers = card, answers
    @features, @reasons = {}, {}
    build_features
  end

  def score
    features.values.sum - penalty
  end

  def explanation
    reasons.sort_by { |key, _| -features.fetch(key, 0) }.first(3).map(&:last)
  end

  # What the user asked for that this card provides, as short fragments the
  # results page reads back to them ("you wanted cashback and no annual fee"),
  # strongest first. Spending categories are left out: the page ties those to
  # the role each card is given in the stack, which can change on a swap.
  def preferences_met
    fragments = features.sort_by { |_, value| -value }.filter_map do |key, _|
      case key
      when "goal:Cashback" then "cashback"
      when "goal:Travel rewards" then "travel rewards"
      when "goal:Keeping costs down", "no_fee" then "no annual fee"
      when "goal:Building credit" then "help building credit" if Array(card.catalogue_terms["quiz_tags"]).include?("Building credit")
      when "simple" then "simple everyday rewards"
      when "flexible" then "categories you can activate"
      when "foreign" then "no foreign transaction fee"
      when /\Aprogram:(.+)/ then Regexp.last_match(1)
      when /\A(benefit:|goal:Useful perks)/ then reasons[key].split(":").first.downcase
      end
    end
    fragments.uniq.first(2)
  end

  # One concrete use for the Results card, in its original earning unit. This
  # describes a qualifying purchase, not a spending allocation or dollar estimate.
  def recommended_uses
    return [] if card.catalogue_status == "retired"
    rules = ongoing_rules.reject { |rule| rule["earning_basis"] == "card_and_booking_channel" }
    categories = (Array(@answers["spending_priorities"]) + SPENDING_CHANNELS.keys).uniq
    uses = categories.filter_map do |category|
      channels = channels_for(category)
      matching = rules.select { |rule| (rule_channels(rule) & channels).any? }
      next if matching.empty?
      rule = matching.max_by { |candidate| candidate["rate"].to_f }
      # Keep the source's qualifying words; never turn "direct flights" into all travel.
      clause = rule["category"].split(/[;,]/).find do |part|
        (rule_channels(rule.merge("category" => part)) & channels).any?
      end
      label = (clause || rule["category"]).strip
      label = "Travel booked directly" if label == "Other travel"
      rule.merge("use_key" => category, "use_for" => label)
    end
    base = rules.find { |rule| rule["category"].match?(/Other purchases|Eligible purchases|Everyday purchases|Purchases and repayment combined/i) }
    fallback = base || rules.first
    uses << fallback.merge("use_key" => "everyday", "use_for" => base ? "Everyday purchases" : fallback["category"]) if fallback
    uses
  end

  def penalty
    management = @answers["first_card_management"] || @answers["next_card_management"]
    simple = ["Simple everyday rewards", "Consistent rewards without activation"].include?(management) ||
      @answers["reward_management"] == "Keep rewards consistent"
    complexity = rotating? && simple ? 3.0 : 0.0
    # Relative fee burden is an editorial preference, not a break-even estimate.
    spend = { "Under $500" => 1, "$500–$1,000" => 1.25, "$1,000–$2,500" => 1.5,
              "$2,500–$5,000" => 1.75, "$5,000+" => 2 }.fetch(@answers["monthly_card_spend"], 1)
    fee_weight = goal_weight("Keeping costs down") + (management == "No annual fee" ? 3 : 0)
    complexity + card.annual_fee.to_f / 100.0 * (0.5 + fee_weight) / spend
  end

  private

  def goal_weight(goal)
    index = Array(@answers["priorities"]).first(3).index(goal)
    index ? [5, 3, 1][index] : 0
  end

  def add(key, value, reason)
    return unless value.positive?
    features[key] = value
    reasons[key] = reason
  end

  def build_features
    rules = ongoing_rules
    base = rules.find { |rule| rule["category"].match?(/Other purchases|Eligible purchases|Everyday purchases|Purchases and repayment combined/i) }
    base_rate = base ? base["rate"].to_f : 0
    cash = rules.any? { |rule| rule["unit"] == "cashback_percent" }
    travel = rules.any? { |rule| %w[points_per_USD miles_per_USD].include?(rule["unit"]) }
    add("goal:Cashback", goal_weight("Cashback") * (cash ? 2 : 0), "Matches your preference for cashback.")
    add("goal:Travel rewards", goal_weight("Travel rewards") * (travel ? 2 : 0), "Earns points or miles, matching your travel-rewards goal.")
    add("goal:Keeping costs down", goal_weight("Keeping costs down") * (card.annual_fee == 0 ? 2 : 0), "No ongoing annual fee, matching your cost preference.")
    builder = Array(card.catalogue_terms["quiz_tags"]).include?("Building credit")
    add("goal:Building credit", goal_weight("Building credit") * (builder ? 2 : 1), "Recorded credit guidance matches the credit profile you provided.")

    Array(@answers["spending_priorities"]).first(3).each_with_index do |category, index|
      channels = channels_for(category)
      # Rent has no supported earning rule in this catalogue. Never assume rent
      # is payable by card or that a processor's fee is covered by rewards.
      matched_rules = []
      coverage = channels.map do |channel|
        next 0 if channel == "rent"
        matching = rules.select { |rule| rule_channels(rule).include?(channel) }
        best = matching.max_by { |rule| rule["rate"].to_f }
        matched_rules << best if best
        baseline = base_rate.positive? ? 0.6 + [base_rate, 2].min * 0.2 : 0
        next baseline unless best
        # Compare a category only with that card's own base earning unit. These
        # bounded coverage scores do not equate one point to one cent.
        uplift = [best["rate"].to_f - base_rate, 0].max
        bonus = [uplift, 3].min * 0.5
        bonus *= 0.75 if best["conditions"].to_s.match?(/cap|then|selected|eligible/i)
        baseline + bonus
      end.sum / [channels.size, 1].max
      management = @answers["first_card_management"] || @answers["next_card_management"]
      focus = ["Rewards focused on my main spending", "One clear spending role"].include?(management) ? 1.4 : 1
      evidence = matched_rules.uniq.presence || (base ? [base] : [])
      terms = evidence.map { |rule| [rule["category"], rule["conditions"].presence].compact.join(": ").sub(/[.!?]\z/, "") }.join("; ")
      add("spend:#{category}", coverage * [4, 2.5, 1.5][index] * focus,
          "For #{category.downcase}#{follow_up_label(category)}: #{terms}. Rewards depend on eligible purchases and merchant coding.")
    end

    management = @answers["first_card_management"] || @answers["next_card_management"]
    if management == "Simple everyday rewards"
      add("simple", [base_rate, 2].min * 2, "Ongoing everyday rewards suit your preference for a simple first card.")
    elsif management == "No annual fee"
      add("no_fee", card.annual_fee == 0 ? 4 : 0, "Matches your request for a card without an annual fee.")
    end
    if @answers["reward_management"] == "I’m happy to activate or choose categories" && rotating?
      add("flexible", 2, "You are comfortable managing categories. Rotating rewards are not counted as permanent spending coverage.")
    end
    foreign = { "Once a year" => 1, "2–4 times a year" => 2, "Monthly or more" => 3,
                "Occasionally" => 1, "Several times a year" => 2, "Every month" => 3 }
    frequency = foreign.fetch(@answers["international_travel"] || @answers["foreign_purchases"], 0)
    add("foreign", frequency * 2, "No recorded foreign transaction fee, matching your foreign-currency use.") if card.foreign_transaction_fee == false
    program = Card::TRAVEL_PROGRAM_CARDS[card.source_key]
    add("program:#{program}", 4, "Matches your named preference for #{program}.") if program && Array(@answers["travel_programs"]).include?(program)
    build_benefits
  end

  def build_benefits
    requested = Array(@answers["useful_benefits"])
    requested = BENEFIT_PATTERNS.keys if requested.empty? && goal_weight("Useful perks").positive?
    requested.first(5).each_with_index do |benefit, index|
      evidence = card.perk_list.select { |perk| perk.match?(BENEFIT_PATTERNS.fetch(benefit)) }
      if benefit == "Dining credits" && @answers["dining_providers"].present?
        # The captured Gold terms establish Uber Cash, but do not name Grubhub.
        evidence.select! { |perk| ["Uber Eats", "Both"].include?(@answers["dining_providers"]) && perk.match?(/Uber Cash/i) }
      elsif benefit == "Shopping or subscription credits" && @answers["credit_providers"].present?
        evidence.select! { |perk| ["Streaming subscriptions", "Both"].include?(@answers["credit_providers"]) && perk.match?(/digital-entertainment|Disney|Hulu|ESPN/i) }
      end
      next if evidence.empty?
      # Without an explicit benefit preference use a modest shared goal score,
      # not five independent reasons to add more premium cards.
      explicit = Array(@answers["useful_benefits"]).present?
      weight = explicit ? [3, 2, 1].fetch(index, 1) : 1
      key = explicit ? "benefit:#{benefit}" : "goal:Useful perks"
      add(key, weight * [goal_weight("Useful perks"), 1].max, "#{benefit}: #{evidence.first}")
    end
  end

  def ongoing_rules
    card.reward_rules.reject { |rule| rule["temporary"] || rule["category"].match?(/introductory|promotion/i) }
  end

  def rotating?
    ongoing_rules.any? { |rule| rule["category"].match?(/quarterly|chosen category/i) }
  end

  def channels_for(category)
    key = FOLLOW_UP_CATEGORIES.key(category)
    FOLLOW_UP_CHANNELS.fetch(key, {}).fetch(@answers[key], SPENDING_CHANNELS.fetch(category, []))
  end

  def follow_up_label(category)
    answer = @answers[FOLLOW_UP_CATEGORIES.key(category)]
    answer.present? ? " — #{answer.downcase}" : ""
  end

  def rule_channels(rule)
    text = rule["category"].downcase
    # Portal and retailer earning cannot be extrapolated to general travel or groceries.
    return %w[amazon portal] if text.include?("amazon.com")
    return ["portal"] if text.match?(/chase travel|amex travel|capital one travel|citi travel|bofa travel/) && !text.match?(/direct/)
    return [] if text.match?(/quarterly|chosen category|entertainment bookings/)
    channels = []
    channels << "online_grocery" if text.include?("online groceries")
    channels << "supermarket" if text.match?(/supermarkets|grocery stores|groceries/) && !text.include?("online groceries")
    channels << "wholesale" if text.include?("wholesale clubs")
    channels << "dining" if text.match?(/dining|restaurants/)
    channels << "delivery" if rule["conditions"].to_s.match?(/delivery included/i)
    channels << "gas" if text.match?(/gas/)
    channels << "ev" if text.match?(/ev charging/)
    channels << "transit" if text.match?(/transit/)
    channels << "streaming" if text.match?(/streaming/)
    channels << "events" if text.match?(/entertainment/)
    channels.concat(%w[online_retail amazon]) if text.include?("online retail")
    channels << "phone" if text.include?("phone plans")
    channels << "direct_travel" if text.match?(/other travel|direct|air travel|travel,/) && !text.match?(/united|southwest|delta|hilton|hyatt|marriott/)
    channels
  end
end
