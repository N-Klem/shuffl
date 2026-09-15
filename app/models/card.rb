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

  # One ten-question journey. The highest-ranked goal chooses the final two
  # questions; all visitors answer the same eight foundational questions.
  QUESTION_POOL = {
    "priorities" => {
      key: "priorities", type: :ranked, max_select: 3,
      prompt: "What matters most in your next card?",
      options: [ "Building credit", "Cashback", "Travel rewards", "Keeping costs down", "Useful perks" ]
    },
    # Ownership adds context without limiting the available goals.
    "open_credit_cards" => {
      key: "open_credit_cards",
      type: :single,
      prompt: "How many credit cards do you currently have?",
      options: [ "None right now", "1–2", "3–5", "6+" ]
    },

    # Shared pool — drawn into paths as needed
    "credit_score" => {
      key: "credit_score",
      type: :single,
      prompt: "What's your credit score range?",
      options: [ "No credit history", "Building (300–579)", "Fair (580–669)", "Good (670–739)", "Excellent (740+)", "I don't know" ]
    },
    "pays_in_full" => {
      key: "pays_in_full",
      type: :single,
      prompt: "Do you pay your balance off in full each month?",
      options: [ "Yes, always", "Usually", "Sometimes I carry a balance", "I carry a balance most months" ]
    },
    "employment_status" => {
      key: "employment_status",
      type: :single,
      prompt: "What's your employment status?",
      options: [ "Student", "Employed full-time", "Employed part-time", "Self-employed or freelance", "Unemployed" ]
    },
    "annual_income" => {
      key: "annual_income",
      type: :single,
      prompt: "What's your annual income?",
      options: [ "Under $20k", "$20k–$40k", "$40k–$75k", "$75k–$100k", "$100k–$150k", "$150k+" ]
    },
    "spending_priorities" => {
      key: "spending_priorities",
      type: :ranked,
      max_select: 3,
      prompt: "Where does most of your money go?",
      options: [ "Groceries", "Dining out", "Travel", "Gas & transport", "Online shopping", "Entertainment & subscriptions", "Rent or bills" ]
    },
    "annual_fee_tolerance" => {
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
    "rewards_type" => {
      key: "rewards_type",
      type: :single,
      prompt: "What kind of rewards do you care about most?",
      options: [ "Cashback", "Travel points & miles", "Dining & food credits", "Statement credits or discounts" ]
    },
    "international_travel" => {
      key: "international_travel",
      type: :single,
      prompt: "How often do you travel internationally?",
      options: [ "Never", "Once a year", "2–4 times a year", "Monthly or more" ]
    },
    "monthly_card_spend" => {
      key: "monthly_card_spend",
      type: :single,
      prompt: "How much could you put on a card each month, roughly?",
      options: [ "Under $500", "$500–$1,000", "$1,000–$2,500", "$2,500–$5,000", "$5,000+" ]
    },
    "signup_bonus_interest" => {
      key: "signup_bonus_interest",
      type: :single,
      prompt: "Are you interested in sign-up bonuses?",
      options: [
        "Yes, I'd spend enough to hit a bonus target",
        "Maybe, depends on the requirement",
        "No, I want long-term value over one-time bonuses"
      ]
    },
    "perks_interest" => {
      key: "perks_interest",
      type: :single,
      prompt: "Would you use perks like purchase protection, extended warranty, or cell phone insurance?",
      options: [ "Yes, that's a big deal for me", "Nice to have", "Wouldn't think about it" ]
    },
    "documented_income" => {
      key: "documented_income",
      type: :single,
      prompt: "Do you have a regular source of income you can document?",
      options: [ "Yes, steady paycheck", "Yes, but it varies", "I have savings but no regular income", "No" ]
    },
    "online_shopping" => {
      key: "online_shopping",
      type: :single,
      prompt: "Do you shop a lot online?",
      options: [ "Yes, most of my purchases", "Some, but I shop in-store too", "Rarely" ]
    },
    "loyalty_program" => {
      key: "loyalty_program",
      type: :single,
      prompt: "Do you have a preferred airline or hotel chain?",
      options: [ "Yes — I'm loyal to one brand", "I have a slight preference", "No, whatever is cheapest" ]
    }
  }.freeze

  COMMON_QUESTION_KEYS = %w[priorities open_credit_cards credit_score pays_in_full spending_priorities monthly_card_spend annual_fee_tolerance employment_status].freeze
  GOAL_QUESTIONS = {
    "Building credit" => %w[documented_income annual_income],
    "Cashback" => %w[online_shopping signup_bonus_interest],
    "Travel rewards" => %w[international_travel signup_bonus_interest],
    "Keeping costs down" => %w[international_travel annual_income],
    "Useful perks" => %w[perks_interest international_travel]
  }.freeze

  # Compatibility map for completed results from the previous branching quiz.
  IMPLICIT_SCORING = {
    # Beginner
    "Build my credit score"              => { "top_priority" => "Building credit" },
    "Start earning rewards"              => { "top_priority" => "Earning rewards" },
    "Just need a card — keep it simple"  => { "top_priority" => "Low fees" },

    # Growing
    "Better travel rewards"              => { "top_priority" => "Earning rewards", "rewards_type" => "Travel points & miles" },
    "More cashback on everyday spending" => { "top_priority" => "Earning rewards", "rewards_type" => "Cashback" },
    "Premium perks and benefits"         => { "top_priority" => "Premium perks & status" },

    # Optimizer
    "A dedicated travel card"            => { "top_priority" => "Earning rewards", "rewards_type" => "Travel points & miles" },
    "Better cashback coverage"           => { "top_priority" => "Earning rewards", "rewards_type" => "Cashback" },
    "Premium perks and status"           => { "top_priority" => "Premium perks & status" }
  }.freeze

  QUIZ_LENGTH_RANGE = (10..10).freeze

  def self.quiz_questions_for(answers)
    goal = Array(answers["priorities"]).first
    extras = GOAL_QUESTIONS.fetch(goal, GOAL_QUESTIONS["Building credit"])
    (COMMON_QUESTION_KEYS + extras).map do |key|
      question = QUESTION_POOL.fetch(key)
      if key == "pays_in_full" && ["None right now", "None, this would be my first"].include?(answers["open_credit_cards"])
        question.merge(prompt: "Would you expect to pay your card balance in full each month?",
                       options: question[:options] + ["I'm not sure yet"])
      else
        question
      end
    end
  end

  # Retain interpretation of completed quizzes from the previous version.
  def self.scored_answers(answers)
    return answers.except("top_priority", "rewards_type") if answers["priorities"].present?
    legacy_choice = answers.values.find { |value| value.is_a?(String) && IMPLICIT_SCORING.key?(value) }
    (IMPLICIT_SCORING[legacy_choice] || {}).merge(answers)
  end

  def self.ranked_for(answers)
    merged = scored_answers(answers)
    all.sort_by { |card| -card.quiz_score(merged) }
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
    if answers["priorities"].present?
      score += Array(answers["priorities"]).first(3).each_with_index.sum do |goal, index|
        value = case goal
                when "Building credit" then top_priority_score("Building credit", cats)
                when "Keeping costs down" then top_priority_score("Low fees", cats)
                when "Cashback" then rewards_type_score("Cashback", cats)
                when "Travel rewards" then rewards_type_score("Travel points & miles", cats)
                when "Useful perks" then perks_interest_score("Yes, that's a big deal for me")
                else 0
                end
        value * (3 - index) / 3.0
      end
    else
      score += top_priority_score(answers["top_priority"], cats)
    end

    score
  end

  private

  def spending_priorities_score(answer, cats, multiplier)
    ranked = Array(answer)
    return 0 if ranked.empty?

    ranked.first(3).each_with_index.sum do |expense, index|
      category = category_for_expense(expense)
      next 0 unless category && cats.include?(category)
      ((3 - index) * multiplier).round
    end
  end

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

  def open_cards_bonus(answer)
    return 0 if credit_score_min.nil? || credit_score_min > 650

    { "None right now" => 2, "None, this would be my first" => 2, "1–2" => 1 }[answer].to_i
  end

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
      0
    when "Premium perks & status"
      annual_fee.to_i >= 250 ? 3 : 0
    else
      0
    end
  end
end
