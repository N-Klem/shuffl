class Card < ApplicationRecord
  # Read the small manifest on demand so newly added artwork is available
  # without restarting an already-running development server.
  def self.image_paths
    JSON.parse(Rails.root.join("config/card_images.json").read)
  end

  def image_path
    self.class.image_paths[source_key]
  end

  has_many :wallet_items, dependent: :destroy
  has_many :users, through: :wallet_items
  has_many :stack_cards, dependent: :destroy
  has_many :stacks, through: :stack_cards

  validates :name, :issuer, :card_type, presence: true
  validates :network, presence: true, unless: :real_catalogue?
  validates :source_key, uniqueness: true, allow_nil: true
  validates :catalogue_status, inclusion: { in: %w[legacy draft published retired] }
  validates :country, inclusion: { in: ["US"] }, if: :real_catalogue?
  validates :currency, inclusion: { in: ["USD"] }, if: :real_catalogue?
  validates :annual_fee,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reward_rate,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :available, -> { where(catalogue_status: %w[legacy published]) }

  def real_catalogue?
    source_key.present?
  end

  # Candidate research is the source of truth; repeated imports update by stable
  # identity, never by a marketing name. Importing does not publish or retire.
  def self.import_us_candidates!
    candidates = CardCandidate.where(country: "US").where.not(review_status: "rejected").in_shortlist_order
    raise ArgumentError, "No US candidates to import" if candidates.empty?

    transaction do
      candidates.each do |candidate|
        raise ActiveRecord::RecordInvalid, candidate unless candidate.valid?
        facts = candidate.research.deep_dup
        card = find_or_initialize_by(source_key: candidate.source_key)
        card.catalogue_status = "draft" if card.new_record?
        card.assign_attributes(name: candidate.name, issuer: facts.fetch("issuer"),
          country: "US", currency: "USD", network: facts["network"],
          card_type: facts["product_kind"].presence || "credit_card",
          annual_fee: facts.dig("fees", "annual"), reward_rate: nil,
          foreign_transaction_fee: facts.dig("fees", "foreign_purchase_percent").nil? ? nil : facts.dig("fees", "foreign_purchase_percent").to_d.positive?,
          credit_score_min: facts["credit_score_min"], welcome_bonus: facts["welcome_offer"],
          perks: Array(facts["perks"]).join(", "), best_for: Array(facts["quiz_tags"]).join(", "),
          description: "#{candidate.name} from #{facts.fetch('issuer')}. Compare the recorded reward rules, fees and offer requirements below.",
          catalogue_terms: facts)
        card.save!
      end
    end
    candidates.size
  end

  def self.publish_us_demo!
    transaction do
      import_us_candidates!
      keys = CardCandidate.where(country: "US").where.not(review_status: "rejected").pluck(:source_key)
      where(source_key: keys).update_all(catalogue_status: "published")
      where(source_key: nil).update_all(catalogue_status: "retired")
      where.not(source_key: nil).where.not(source_key: keys).update_all(catalogue_status: "retired")
    end
  end

  def results_data(index = 0)
    {
      id: id, name: name, imageUrl: image_path, role: best_for.presence || issuer,
      finish: %w[#e7e3da #701d2b #444748 #c7c8c5 #777c80][index % 5],
      ink: [0, 3].include?(index % 5) ? "#242424" : "#fff",
      fee: annual_fee&.to_f, perks: perk_list.first(3),
      rates: real_catalogue? ? Array.new(6) : Array.new(6, 0.0),
      estimatesAvailable: false, rewardSummary: reward_summary, rewardRules: reward_rules,
      welcomeOffer: displayed_welcome_offer, valueProfile: value_profile,
      ongoingFee: RewardsCalculator.ongoing_fee(self)&.to_f,
      spendingSupported: SpendingPlan.profile(self).present?,
      retired: catalogue_status == "retired", use: description,
      url: Rails.application.routes.url_helpers.card_path(self)
    }
  end

  def perk_list
    real_catalogue? ? Array(catalogue_terms["perks"]) : perks.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def reward_rules
    catalogue_terms.fetch("rewards", [])
  end

  # Presentation uses known product facts; a missing earning schedule is never
  # interpreted as a no-rewards card. Calculation support remains separate.
  def displayed_welcome_offer
    return nil if catalogue_terms["welcome_offer_status"] == "none"
    return nil if welcome_bonus.blank? || welcome_bonus.match?(/\A(?:no .*bonus.*listed|offer not captured)/i)
    welcome_bonus
  end

  def value_profile
    rules = reward_rules.reject { |rule| rule["temporary"] || rule["category"].to_s.match?(/introductory|promotion/i) }
    rule = rules.max_by { |reward| reward.fetch("rate").to_d }
    building = catalogue_terms["rewards_status"] == "none" && best_for.to_s.include?("Building credit")
    if building
      { kind: "credit", title: "Build your credit", value: annual_fee == 0 ? "$0" : "Credit building",
        label: annual_fee == 0 ? "Annual fee" : "Card focus",
        detail: "A card for building credit through responsible use. It does not earn purchase rewards.",
        conditions: nil, estimateSupported: false }
    elsif rule
      unit = { "cashback_percent" => "% cashback", "points_per_USD" => " points / $1", "miles_per_USD" => " miles / $1" }.fetch(rule["unit"], " #{rule['unit'].to_s.tr('_', ' ')}")
      kind = rule["unit"] == "cashback_percent" ? "cashback" : "travel"
      { kind: kind, title: kind == "cashback" ? "Cashback on your spending" : "Earn toward your next trip",
        value: "#{rule['rate']}#{unit}", label: rule["category"], detail: rule["category"],
        conditions: rule["conditions"].presence,
        estimateSupported: RewardsCalculator.unavailable_reason(self).nil? }
    else
      { kind: "features", title: "What this card offers", value: best_for.to_s.split(",").first.presence || "Card benefits",
        label: "Card focus", detail: perk_list.first.presence || "Compare this card’s fees and issuer terms.",
        conditions: nil, estimateSupported: false }
    end
  end

  def headline_reward
    return "#{reward_rate.to_f.to_s.delete_suffix('.0')}x" unless real_catalogue?
    rule = reward_rules.max_by { |reward| reward.fetch("rate").to_d }
    return value_profile[:value] unless rule
    "#{rule['rate']}#{rule['unit'] == 'cashback_percent' ? '%' : 'x'}"
  end

  def reward_summary
    return "#{reward_rate.to_f.to_s.delete_suffix('.0')}x rewards" unless real_catalogue?
    rule = reward_rules.max_by { |reward| reward.fetch("rate").to_d }
    return value_profile[:detail] unless rule
    unit = rule["unit"] == "cashback_percent" ? "% cashback" : " #{rule['unit'].tr('_', ' ')}"
    "#{rule['rate']}#{unit} on #{rule['category']}"
  end

  EXPENSE_OPTIONS = [
    "Groceries", "Dining out", "Gas & transport", "Online shopping",
    "Rent or bills", "Travel", "Entertainment & subscriptions"
  ].freeze

  # One ten-question journey. The highest-ranked goal chooses the final two
  # questions; all visitors answer the same eight foundational questions.
  QUESTION_POOL = {
    "priorities" => {
      key: "priorities", type: :ranked, max_select: 3,
      prompt: "What matters most in your stack?",
      options: [ "Building credit", "Cashback", "Travel rewards", "Keeping costs down", "Useful perks" ]
    },
    # Ownership adds context without limiting the available goals.
    "open_credit_cards" => {
      key: "open_credit_cards",
      type: :single,
      prompt: "How many credit cards do you currently have?",
      options: [ "None right now", "1–2", "3–5", "6+" ]
    },

    # Shared pool: drawn into paths as needed
    "credit_score" => {
      key: "credit_score",
      type: :single,
      prompt: "What's your credit score range?",
      options: [ "No credit history", "Building (300–579)", "Fair (580–669)", "Good (670–739)", "Excellent (740+)", "I don't know" ]
    },
    "stack_size" => {
      key: "stack_size",
      type: :single,
      prompt: "What’s the maximum number of cards you’d feel comfortable managing in your stack?",
      options: [ "1", "2", "3", "4", "5", "Recommend for me" ]
    },
    "employment_status" => {
      key: "employment_status",
      type: :single,
      prompt: "Are you currently a college student?",
      options: [ "Student", "Not a student" ]
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
    "annual_fee_budget" => {
      key: "annual_fee_budget", type: :budget,
      prompt: "What’s your maximum annual-fee budget for the whole stack?",
      options: [ "0", "100", "300", "Custom" ]
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
      options: [ "Yes, I'm loyal to one brand", "I have a slight preference", "No, whatever is cheapest" ]
    }
  }.freeze

  # Follow-ups are selected from answers already given, without adding steps.
  FOLLOW_UP_QUESTIONS = {
    "travel_programs" => {
      key: "travel_programs", type: :multi, max_select: 3,
      prompt: "Which airline or hotel programmes do you prefer?",
      options: [ "United MileagePlus", "Southwest Rapid Rewards", "Delta SkyMiles",
                 "Marriott Bonvoy", "World of Hyatt", "Hilton Honors", "Other", "No preference" ],
      exclusive: [ "No preference" ]
    },
    "reward_management" => {
      key: "reward_management", type: :single,
      prompt: "Would you manage changing reward categories, or prefer consistent rewards?",
      options: [ "Keep rewards consistent", "I’m happy to activate or choose categories", "Either works for me" ]
    },
    "first_card_management" => {
      key: "first_card_management", type: :single,
      prompt: "What matters most about managing your first card?",
      options: [ "Simple everyday rewards", "No annual fee", "Rewards focused on my main spending" ]
    },
    "next_card_management" => {
      key: "next_card_management", type: :single,
      prompt: "What would make your next card easier to manage?",
      options: [ "Consistent rewards without activation", "No annual fee", "One clear spending role" ]
    },
    "foreign_purchases" => {
      key: "foreign_purchases", type: :single,
      prompt: "How often do you make purchases in foreign currencies, online or abroad?",
      options: [ "Never", "Occasionally", "Several times a year", "Every month" ]
    },
    "useful_benefits" => {
      key: "useful_benefits", type: :ranked, max_select: 3,
      prompt: "Which benefits would you actually use?",
      options: [ "Airport lounge access", "Airline or hotel benefits", "Dining credits",
                 "Shopping or subscription credits", "Purchase protection or insurance" ]
    },
    "groceries_where" => {
      key: "groceries_where", type: :single, prompt: "Where do you buy most of your groceries?",
      options: [ "Supermarkets", "Walmart or Target", "Wholesale clubs", "Online grocery orders", "A mix of places" ]
    },
    "shopping_where" => {
      key: "shopping_where", type: :single, prompt: "Where do you do most of your online shopping?",
      options: [ "Amazon with Prime", "Amazon without Prime", "Other retailers", "A mix of retailers" ]
    },
    "dining_where" => {
      key: "dining_where", type: :single, prompt: "How do you usually spend on dining?",
      options: [ "Directly with restaurants or cafés", "Delivery apps", "A mix of both" ]
    },
    "travel_booking" => {
      key: "travel_booking", type: :single, prompt: "How do you prefer to book travel?",
      options: [ "Directly with airlines and hotels", "I’m comfortable using a card’s travel portal", "No preference" ]
    },
    "transport_spending" => {
      key: "transport_spending", type: :single, prompt: "What makes up most of your transport spending?",
      options: [ "Gas stations", "EV charging", "Public transport or rideshares", "A mix" ]
    },
    "entertainment_spending" => {
      key: "entertainment_spending", type: :single, prompt: "What makes up most of your entertainment spending?",
      options: [ "Streaming subscriptions", "Live events or cinemas", "A mix" ]
    },
    "bills_spending" => {
      key: "bills_spending", type: :single, prompt: "Which bills make up most of that spending?",
      options: [ "Rent", "Utilities", "Phone bills", "A mix" ]
    },
    "dining_providers" => {
      key: "dining_providers", type: :single, prompt: "Do you already use dining delivery services?",
      options: [ "Uber Eats", "Grubhub", "Both", "Other services", "None" ]
    },
    "credit_providers" => {
      key: "credit_providers", type: :single, prompt: "Where would you naturally use shopping or subscription credits?",
      options: [ "Streaming subscriptions", "Retail purchases", "Both", "Neither, I wouldn’t spend just to use a credit" ]
    }
  }.freeze
  QUIZ_QUESTION_POOL = QUESTION_POOL.merge(FOLLOW_UP_QUESTIONS).freeze
  COMMON_QUESTION_KEYS = %w[priorities open_credit_cards credit_score stack_size spending_priorities monthly_card_spend annual_fee_budget employment_status].freeze
  GOAL_QUESTIONS = {
    "Building credit" => %w[first_card_management groceries_where],
    "Cashback" => %w[reward_management groceries_where],
    "Travel rewards" => %w[travel_programs international_travel],
    "Keeping costs down" => %w[foreign_purchases reward_management],
    "Useful perks" => %w[useful_benefits international_travel]
  }.freeze

  # Compatibility map for completed results from the previous branching quiz.
  IMPLICIT_SCORING = {
    # Beginner
    "Build my credit score"              => { "top_priority" => "Building credit" },
    "Start earning rewards"              => { "top_priority" => "Earning rewards" },
    "Just need a card, keep it simple"    => { "top_priority" => "Low fees" },

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
    spending_question = {
      "Groceries" => "groceries_where", "Dining out" => "dining_where",
      "Travel" => "travel_booking", "Gas & transport" => "transport_spending",
      "Online shopping" => "shopping_where", "Entertainment & subscriptions" => "entertainment_spending",
      "Rent or bills" => "bills_spending"
    }.fetch(Array(answers["spending_priorities"]).first, "groceries_where")
    if spending_question == "shopping_where"
      prime = available.find_by(source_key: "us-prime-visa")
      unless prime&.recommendable_for?(answers.merge("shopping_where" => "Amazon with Prime"))
        spending_question = "foreign_purchases"
      end
    end
    extras = case goal
             when "Building credit"
               first_card = ["None right now", "None, this would be my first"].include?(answers["open_credit_cards"])
               [first_card ? "first_card_management" : "next_card_management", spending_question]
             when "Cashback" then ["reward_management", spending_question]
             when "Useful perks"
               follow_up = case Array(answers["useful_benefits"]).first
                           when "Airline or hotel benefits" then "travel_programs"
                           when "Dining credits" then "dining_providers"
                           when "Shopping or subscription credits" then "credit_providers"
                           when "Purchase protection or insurance" then spending_question
                           else "international_travel"
                           end
               ["useful_benefits", follow_up]
             else GOAL_QUESTIONS.fetch(goal, GOAL_QUESTIONS["Building credit"])
             end
    (COMMON_QUESTION_KEYS + extras).map do |key|
      question = QUIZ_QUESTION_POOL.fetch(key)
      if key == "first_card_management" && answers["employment_status"] == "Student"
        question.merge(prompt: "As a student, what matters most about managing your first card?")
      else
        question
      end
    end
  end

  def self.valid_quiz_answer?(question, answer)
    values = Array(answer)
    if question[:type] == :budget
      return values.size == 1 && values.first.is_a?(String) && values.first.match?(/\A\d{1,6}(?:\.\d{1,2})?\z/)
    end
    max = [:multi, :ranked].include?(question[:type]) ? question[:max_select] : 1
    values.size.between?(1, max) && values.uniq == values &&
      (values - question[:options]).empty? &&
      (values.size == 1 || (values & Array(question[:exclusive])).empty?)
  end

  def self.stack_size_limit(answers)
    choice = answers["stack_size"]
    %w[1 2 3 4 5].include?(choice) ? choice.to_i : 5
  end

  # Retain interpretation of completed quizzes from the previous version.
  def self.scored_answers(answers)
    return answers.except("top_priority", "rewards_type") if answers["priorities"].present?
    choices = answers.values.grep(String).map { |value| value.gsub(/\s*\p{Pd}\s*/, ", ") }
    legacy_choice = choices.find { |value| IMPLICIT_SCORING.key?(value) }
    (IMPLICIT_SCORING[legacy_choice] || {}).merge(answers)
  end

  TRAVEL_PROGRAM_CARDS = {
    "us-united-explorer" => "United MileagePlus",
    "us-southwest-plus" => "Southwest Rapid Rewards",
    "us-delta-gold" => "Delta SkyMiles",
    "us-marriott-boundless" => "Marriott Bonvoy",
    "us-world-of-hyatt" => "World of Hyatt",
    "us-hilton-aspire" => "Hilton Honors"
  }.freeze

  def self.ranked_for(answers)
    merged = scored_answers(answers)
    available.select { |card| card.recommendable_for?(answers) }
             .sort_by { |card| [-card.quiz_score(merged), card.id] }
  end

  # Editorial suitability, not issuer approval thresholds. Missing guidance or
  # an unknown score cannot establish a match. New credit is not damaged credit.
  CREDIT_PROFILE_MATCHES = {
    "new_to_credit" => ["No credit history"],
    "limited_or_no_credit_history" => ["No credit history", "Fair (580–669)", "Good (670–739)", "Excellent (740+)"],
    "fair_to_average" => ["Fair (580–669)", "Good (670–739)", "Excellent (740+)"],
    "good_to_excellent" => ["Good (670–739)", "Excellent (740+)"],
    "excellent" => ["Excellent (740+)"]
  }.freeze

  def recommendable_for?(answers)
    return true unless real_catalogue?

    # "I don't know" skips the credit-profile filter rather than ending the quiz
    # with nothing; the results page says the matches don't account for it.
    band = catalogue_terms.dig("editorial_credit_guidance", "band")
    return false unless answers["credit_score"] == "I don't know" || CREDIT_PROFILE_MATCHES.fetch(band, []).include?(answers["credit_score"])

    # A suitability tag (e.g. Freedom Rise's Student tag) is not a requirement.
    conditions = Array(catalogue_terms["recommendation_conditions"])
    return false if conditions.include?("Student status") && answers["employment_status"] != "Student"
    return false if source_key == "us-prime-visa" && answers["shopping_where"] != "Amazon with Prime"

    program = TRAVEL_PROGRAM_CARDS[source_key]
    program.nil? || Array(answers["travel_programs"]).include?(program)
  end

  def quiz_score(answers)
    return QuizCardFit.new(self, answers).score if real_catalogue? && answers["priorities"].present?

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

    return 0 if foreign_transaction_fee.nil?

    foreign_transaction_fee? ? -weight : weight
  end

  def loyalty_bonus(answer, cats)
    answer == "Yes, I'm loyal to one brand" && cats.include?("Travel") ? 1 : 0
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
