class Card < ApplicationRecord
  has_many :wallet_items, dependent: :destroy
  has_many :users, through: :wallet_items
  has_many :messages, dependent: :nullify

  validates :name, :issuer, :network, :card_type, presence: true
  validates :annual_fee,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reward_rate,
            numericality: { greater_than_or_equal_to: 0 }

  QUIZ_QUESTIONS = [
    {
      key: "top_priority",
      type: :single,
      prompt: "What is your absolute top priority?",
      options: [ "Dining out", "Groceries", "Travel", "Gas", "Streaming & subscriptions", "A bit of everything" ]
    },
    {
      key: "other_priorities",
      type: :multi,
      max_select: 3,
      prompt: "What other things matter to you? (pick up to 3)",
      options: [ "Dining out", "Groceries", "Travel", "Gas", "Streaming & subscriptions" ]
    },
    {
      key: "dining_frequency",
      type: :single,
      prompt: "How often do you eat out or order delivery?",
      options: [ "Rarely", "A few times a month", "A few times a week", "Almost daily" ]
    },
    {
      key: "travel_frequency",
      type: :single,
      prompt: "How often do you travel?",
      options: [ "Rarely", "A couple trips a year", "Monthly", "I'm always on the go" ]
    },
    {
      key: "annual_fee_tolerance",
      type: :single,
      prompt: "How do you feel about annual fees?",
      options: [
        "No fee",
        "I'd pay up to $100 if the perks are worth it",
        "I'd pay $100-250 for strong rewards",
        "I'll pay $250+ for premium perks"
      ]
    },
    {
      key: "international_travel",
      type: :single,
      prompt: "Do you travel internationally?",
      options: [ "No", "Occasionally", "Frequently" ]
    },
    {
      key: "credit_score",
      type: :single,
      prompt: "How would you describe your credit?",
      options: [ "Just starting out", "Fair", "Building it up", "Good", "Excellent" ]
    },
    {
      key: "rewards_type",
      type: :single,
      prompt: "What matters more to you: cashback or points?",
      options: [ "Simple cashback", "Points I can transfer to airlines or hotels", "I don't mind either way" ]
    },
    {
      key: "welcome_bonus_importance",
      type: :single,
      prompt: "How important is a welcome bonus to you?",
      options: [ "Very - I want the biggest sign-up offer", "Nice to have, but not a dealbreaker", "Don't care" ]
    },
    {
      key: "student",
      type: :single,
      prompt: "Are you a student?",
      options: [ "Yes", "No" ]
    },
    {
      key: "drives_regularly",
      type: :single,
      prompt: "Do you drive regularly?",
      options: [ "Yes, it's my main transport", "Sometimes", "Rarely or never" ]
    },
    {
      key: "streaming_spend",
      type: :single,
      prompt: "How much do you spend on streaming and subscriptions?",
      options: [ "Under $20/month", "$20-50/month", "$50+/month" ]
    }
  ].freeze

  def self.ranked_for(answers)
    all.sort_by { |card| -card.quiz_score(answers) }
  end

  def quiz_score(answers)
    cats = best_for.to_s.split(",").map(&:strip)
    score = 0

    score += 3 if cats.include?(category_for_priority(answers["top_priority"]))
    Array(answers["other_priorities"]).each do |priority|
      score += 1 if cats.include?(category_for_priority(priority))
    end

    score += dining_frequency_weight(answers["dining_frequency"]) if cats.include?("Dining")
    score += travel_frequency_weight(answers["travel_frequency"]) if cats.include?("Travel")
    score += drive_weight(answers["drives_regularly"]) if cats.include?("Gas")
    score += streaming_weight(answers["streaming_spend"]) if cats.include?("Streaming")

    score += fee_fit_score(answers["annual_fee_tolerance"])
    score += credit_fit_score(answers["credit_score"])
    score += international_fit_score(answers["international_travel"])
    score += rewards_type_score(answers["rewards_type"], cats)
    score += welcome_bonus_score(answers["welcome_bonus_importance"])
    score += 3 if answers["student"] == "Yes" && cats.include?("Student")

    score
  end

  private

  def category_for_priority(priority)
    {
      "Dining out" => "Dining",
      "Groceries" => "Groceries",
      "Travel" => "Travel",
      "Gas" => "Gas",
      "Streaming & subscriptions" => "Streaming"
    }[priority]
  end

  def dining_frequency_weight(answer)
    { "Rarely" => 0, "A few times a month" => 1, "A few times a week" => 2, "Almost daily" => 3 }[answer].to_i
  end

  def travel_frequency_weight(answer)
    { "Rarely" => 0, "A couple trips a year" => 1, "Monthly" => 2, "I'm always on the go" => 3 }[answer].to_i
  end

  def drive_weight(answer)
    { "Yes, it's my main transport" => 3, "Sometimes" => 1, "Rarely or never" => 0 }[answer].to_i
  end

  def streaming_weight(answer)
    { "Under $20/month" => 0, "$20-50/month" => 1, "$50+/month" => 2 }[answer].to_i
  end

  def fee_fit_score(answer)
    max_fee = {
      "No fee" => 0,
      "I'd pay up to $100 if the perks are worth it" => 100,
      "I'd pay $100-250 for strong rewards" => 250,
      "I'll pay $250+ for premium perks" => Float::INFINITY
    }[answer]
    return 0 if max_fee.nil?

    annual_fee.to_i <= max_fee ? 2 : -2
  end

  def credit_fit_score(answer)
    target = { "Just starting out" => 580, "Fair" => 630, "Building it up" => 670, "Good" => 700, "Excellent" => 750 }[answer]
    return 0 if target.nil? || credit_score_min.nil?

    credit_score_min <= target ? 2 : -3
  end

  def international_fit_score(answer)
    weight = { "No" => 0, "Occasionally" => 1, "Frequently" => 2 }[answer].to_i
    return 0 if weight.zero?

    foreign_transaction_fee? ? -weight : weight
  end

  def rewards_type_score(answer, cats)
    is_cashback = cats.include?("Cashback")
    case answer
    when "Simple cashback" then is_cashback ? 2 : 0
    when "Points I can transfer to airlines or hotels" then is_cashback ? 0 : 2
    else 0
    end
  end

  def welcome_bonus_score(answer)
    weight = { "Very - I want the biggest sign-up offer" => 3, "Nice to have, but not a dealbreaker" => 1, "Don't care" => 0 }[answer].to_i
    return 0 if weight.zero?

    has_bonus = welcome_bonus.present? && welcome_bonus != "None"
    has_bonus ? weight : 0
  end
end
