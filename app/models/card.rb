class Card < ApplicationRecord
  has_many :wallet_items, dependent: :destroy
  has_many :users, through: :wallet_items
  has_many :stack_cards, dependent: :destroy
  has_many :stacks, through: :stack_cards

  validates :name, :issuer, :network, :card_type, presence: true
  validates :annual_fee,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reward_rate,
            numericality: { greater_than_or_equal_to: 0 }

  EXPENSE_OPTIONS = [
    "Groceries", "Dining out", "Gas & transport", "Online shopping",
    "Rent or bills", "Travel", "Entertainment & subscriptions"
  ].freeze

  # The quiz is in two parts. CORE runs before results; REFINE is offered on the
  # results page for anyone who wants a sharper answer. Both feed the same scorer,
  # and every scoring method treats a missing answer as zero, so a visitor who
  # never refines still gets a complete ranking from the core ten.
  CORE_QUESTIONS = [
    {
      key: "credit_score",
      type: :single,
      prompt: "What's your credit score range?",
      options: [ "No credit history", "Building (300–579)", "Fair (580–669)", "Good (670–739)", "Excellent (740+)", "I don't know" ]
    },
    {
      key: "pays_in_full",
      type: :single,
      prompt: "Do you pay your balance off in full each month?",
      options: [ "Yes, always", "Usually", "Sometimes I carry a balance", "I carry a balance most months" ]
    },
    {
      key: "employment_status",
      type: :single,
      prompt: "What's your employment status?",
      options: [ "Student", "Employed full-time", "Employed part-time", "Self-employed or freelance", "Unemployed" ]
    },
    {
      key: "annual_income",
      type: :single,
      prompt: "What's your annual income?",
      options: [ "Under $20k", "$20k–$40k", "$40k–$75k", "$75k–$100k", "$100k–$150k", "$150k+" ]
    },
    {
      key: "open_credit_cards",
      type: :single,
      prompt: "How many credit cards do you already have?",
      options: [ "None, this would be my first", "1–2", "3–5", "6+" ]
    },
    {
      key: "spending_priorities",
      type: :ranked,
      max_select: 3,
      prompt: "Where does most of your money go? Pick your top three, in order.",
      options: [ "Groceries", "Dining out", "Travel", "Gas & transport", "Online shopping", "Entertainment & subscriptions", "Rent or bills" ]
    },
    {
      key: "annual_fee_tolerance",
      type: :single,
      prompt: "How do you feel about annual fees?",
      options: [
        "No annual fee only",
        "I'd pay up to $100/year if the perks justify it",
        "I'd pay $100–$300 for premium perks",
        "I'd pay $300+ for top-tier benefits"
      ]
    },
    {
      key: "top_priority",
      type: :single,
      prompt: "What's your #1 priority in a credit card?",
      options: [ "Building credit", "Earning rewards", "Low fees", "Low interest rate", "Premium perks & status" ]
    },
    {
      key: "rewards_type",
      type: :single,
      # Only meaningful once someone has said rewards are the point. Asking a
      # credit-builder which points currency they prefer wastes a screen.
      depends_on: { key: "top_priority", value: "Earning rewards" },
      prompt: "What kind of rewards do you care about most?",
      options: [ "Cashback", "Travel points & miles", "Dining & food credits", "Statement credits or discounts" ]
    },
    {
      key: "international_travel",
      type: :single,
      prompt: "How often do you travel internationally?",
      options: [ "Never", "Once a year", "2–4 times a year", "Monthly or more" ]
    }
  ].freeze

  # Offered after results, for anyone who wants to refine. Cut from the core set
  # because each is either low-variance (nearly everyone answers the same way) or
  # redundant with a core question.
  REFINE_QUESTIONS = [
    {
      key: "monthly_card_spend",
      type: :single,
      prompt: "How much do you spend per month on your card(s), roughly?",
      options: [ "Under $500", "$500–$1,000", "$1,000–$2,500", "$2,500–$5,000", "$5,000+" ]
    },
    {
      key: "signup_bonus_interest",
      type: :single,
      prompt: "Are you interested in sign-up bonuses?",
      options: [
        "Yes, I'd spend enough to hit a bonus target",
        "Maybe, depends on the requirement",
        "No, I want long-term value over one-time bonuses"
      ]
    },
    {
      key: "perks_interest",
      type: :single,
      prompt: "Would you use perks like purchase protection, extended warranty, or cell phone insurance?",
      options: [ "Yes, that's a big deal for me", "Nice to have", "Wouldn't think about it" ]
    },
    {
      key: "documented_income",
      type: :single,
      prompt: "Do you have a regular source of income you can document?",
      options: [ "Yes, steady paycheck", "Yes, but it varies", "I have savings but no regular income", "No" ]
    },
    {
      key: "online_shopping",
      type: :single,
      prompt: "Do you shop a lot online?",
      options: [ "Yes, most of my purchases", "Some, but I shop in-store too", "Rarely" ]
    },
    {
      key: "loyalty_program",
      type: :single,
      prompt: "Do you have a preferred airline or hotel chain?",
      options: [ "Yes — I'm loyal to one brand", "I have a slight preference", "No, whatever is cheapest" ]
    }
  ].freeze

  QUIZ_QUESTIONS = (CORE_QUESTIONS + REFINE_QUESTIONS).freeze

  def self.ranked_for(answers)
    all.sort_by { |card| -card.quiz_score(answers) }
  end

  def quiz_score(answers)
    cats = best_for.to_s.split(",").map(&:strip)
    score = 0

    score += credit_fit_score(answers["credit_score"])
    score += open_cards_bonus(answers["open_credit_cards"])
    score += income_fee_bonus(answers["annual_income"])
    score += employment_bonus(answers["employment_status"], cats)
    score += documented_income_bonus(answers["documented_income"])

    score += spending_priorities_score(answers["spending_priorities"], cats,
                                       spend_multiplier(answers["monthly_card_spend"]))
    score += interest_priority_score(answers["pays_in_full"])

    score += rewards_type_score(answers["rewards_type"], cats)
    score += perks_interest_score(answers["perks_interest"])
    score += signup_bonus_score(answers["signup_bonus_interest"])
    score += fee_fit_score(answers["annual_fee_tolerance"])
    score += international_fit_score(answers["international_travel"])
    score += loyalty_bonus(answers["loyalty_program"], cats)
    score += online_shopping_bonus(answers["online_shopping"], cats)
    score += top_priority_score(answers["top_priority"], cats)

    score
  end

  private

  # A ranked top three, weighted 3 / 2 / 1 by position. This replaces the old
  # biggest_expense + second_expense pair: one question, more signal, and the
  # ordering maps straight onto the shape of a two- or three-card stack.
  # monthly_card_spend is a refine-only question now, so the multiplier is 1.0
  # for anyone who has not refined.
  def spending_priorities_score(answer, cats, multiplier)
    ranked = Array(answer)
    return 0 if ranked.empty?

    ranked.first(3).each_with_index.sum do |expense, index|
      category = category_for_expense(expense)
      next 0 unless category && cats.include?(category)
      ((3 - index) * multiplier).round
    end
  end

  # Someone who carries a balance pays more in interest than any realistic
  # rewards rate returns, so rewards-heavy cards stop being the right answer.
  # There is no APR field on Card yet, so this currently only steers toward
  # no-fee cards; when real interest-rate data lands this is where it goes.
  def interest_priority_score(answer)
    case answer
    when "Sometimes I carry a balance" then annual_fee.to_i.zero? ? 1 : -1
    when "I carry a balance most months" then annual_fee.to_i.zero? ? 2 : -3
    else 0
    end
  end

  def category_for_expense(expense)
    {
      "Groceries" => "Groceries",
      "Dining out" => "Dining",
      "Gas & transport" => "Gas",
      "Online shopping" => "Cashback",
      "Rent or bills" => nil,
      "Travel" => "Travel",
      "Entertainment & subscriptions" => "Streaming"
    }[expense]
  end

  def spend_multiplier(answer)
    {
      "Under $500" => 1.0,
      "$500–$1,000" => 1.25,
      "$1,000–$2,500" => 1.5,
      "$2,500–$5,000" => 1.75,
      "$5,000+" => 2.0
    }[answer] || 1.0
  end

  def credit_fit_score(answer)
    target = {
      "No credit history" => 550,
      "Building (300–579)" => 550,
      "Fair (580–669)" => 625,
      "Good (670–739)" => 705,
      "Excellent (740+)" => 760
    }[answer]
    return 0 if target.nil? || credit_score_min.nil?

    credit_score_min <= target ? 2 : -3
  end

  # A first card or an early one is a stronger signal to favor accessible,
  # lower-credit-requirement cards than someone who already has several.
  def open_cards_bonus(answer)
    return 0 if credit_score_min.nil? || credit_score_min > 650

    { "No, this would be my first" => 2, "1–2" => 1 }[answer].to_i
  end

  # Higher income nudges toward premium annual fees being affordable; lower
  # income nudges toward no-fee cards. This is a secondary signal alongside
  # the direct annual_fee_tolerance answer, not a replacement for it.
  def income_fee_bonus(answer)
    income = {
      "Under $20k" => 15_000, "$20k–$40k" => 30_000, "$40k–$75k" => 57_500,
      "$75k–$100k" => 87_500, "$100k–$150k" => 125_000, "$150k+" => 175_000
    }[answer]
    return 0 if income.nil?

    return 1 if income >= 100_000 && annual_fee.to_i >= 250
    return 1 if income < 40_000 && annual_fee.to_i.zero?

    0
  end

  def employment_bonus(answer, cats)
    case answer
    when "Student"
      cats.include?("Student") ? 3 : 0
    when "Unemployed"
      score = 0
      score += 2 if credit_score_min.present? && credit_score_min <= 650
      score += 1 if annual_fee.to_i.zero?
      score
    else
      0
    end
  end

  # No documentable income is an accessibility signal, same direction as
  # the "unemployed" case above.
  def documented_income_bonus(answer)
    return 0 unless [ "No", "I have savings but no regular income" ].include?(answer)
    return 0 unless (credit_score_min.present? && credit_score_min <= 650) || annual_fee.to_i.zero?

    1
  end

  def rewards_type_score(answer, cats)
    case answer
    when "Cashback" then cats.include?("Cashback") ? 2 : 0
    when "Travel points & miles" then cats.include?("Travel") ? 2 : 0
    when "Dining & food credits" then cats.include?("Dining") ? 2 : 0
    when "Statement credits or discounts" then perks.to_s.match?(/credit|discount/i) ? 1 : 0
    else 0
    end
  end

  def perks_interest_score(answer)
    weight = { "Yes, that's a big deal for me" => 3, "Nice to have" => 1, "Wouldn't think about it" => 0 }[answer].to_i
    return 0 if weight.zero?

    perks.to_s.match?(/protect|warrant|insurance/i) ? weight : 0
  end

  def signup_bonus_score(answer)
    weight = {
      "Yes, I'd spend enough to hit a bonus target" => 3,
      "Maybe, depends on the requirement" => 1,
      "No, I want long-term value over one-time bonuses" => 0
    }[answer].to_i
    return 0 if weight.zero?

    has_bonus = welcome_bonus.present? && welcome_bonus != "None"
    has_bonus ? weight : 0
  end

  def fee_fit_score(answer)
    max_fee = {
      "No annual fee only" => 0,
      "I'd pay up to $100/year if the perks justify it" => 100,
      "I'd pay $100–$300 for premium perks" => 300,
      "I'd pay $300+ for top-tier benefits" => Float::INFINITY
    }[answer]
    return 0 if max_fee.nil?

    annual_fee.to_i <= max_fee ? 2 : -2
  end

  def international_fit_score(answer)
    weight = { "Never" => 0, "Once a year" => 1, "2–4 times a year" => 2, "Monthly or more" => 3 }[answer].to_i
    return 0 if weight.zero?

    foreign_transaction_fee? ? -weight : weight
  end

  # Brand loyalty only pays off on a transferable-points travel card - it's
  # a soft reinforcement of the travel signal, not its own dimension.
  def loyalty_bonus(answer, cats)
    answer == "Yes — I'm loyal to one brand" && cats.include?("Travel") ? 1 : 0
  end

  def online_shopping_bonus(answer, cats)
    case answer
    when "Yes, most of my purchases"
      perks.to_s.match?(/online/i) ? 2 : (cats.include?("Cashback") ? 1 : 0)
    when "Some, but I shop in-store too"
      cats.include?("Cashback") ? 1 : 0
    else
      0
    end
  end

  def top_priority_score(answer, cats)
    case answer
    when "Building credit"
      score = 0
      score += 3 if credit_score_min.present? && credit_score_min <= 650
      score += 2 if cats.include?("Student")
      score
    when "Earning rewards"
      (reward_rate.to_f * 1.5).round
    when "Low fees"
      annual_fee.to_i.zero? ? 3 : -1
    when "Low interest rate"
      # Card has no APR/interest-rate field, so this is intentionally a
      # no-op rather than a fabricated signal.
      0
    when "Premium perks & status"
      annual_fee.to_i >= 250 ? 3 : 0
    else
      0
    end
  end
end
