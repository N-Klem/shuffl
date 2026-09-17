ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizRecommendationTest < ActiveSupport::TestCase
  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    @answers = { "priorities" => ["Cashback"], "credit_score" => "Good (670–739)",
      "employment_status" => "Not a student", "stack_size" => "3", "open_credit_cards" => "1–2",
      "annual_fee_budget" => "100", "monthly_card_spend" => "$1,000–$2,500",
      "spending_priorities" => ["Groceries", "Dining out", "Online shopping"] }
  end

  def fit(key, extra = {})
    QuizCardFit.new(Card.find_by!(source_key: key), @answers.merge(extra))
  end

  def spending(key, category, extra)
    fit(key, extra.merge("spending_priorities" => [category])).features.fetch("spend:#{category}", 0)
  end

  test "supermarket bonuses are not counted at superstores or wholesale clubs" do
    key = "us-amex-blue-cash-preferred"
    regular = spending(key, "Groceries", "groceries_where" => "Supermarkets")
    ["Walmart or Target", "Wholesale clubs", "Online grocery orders"].each do |place|
      assert_operator regular, :>, spending(key, "Groceries", "groceries_where" => place)
    end
    assert_operator spending("us-chase-sapphire-preferred", "Groceries", "groceries_where" => "Online grocery orders"), :>,
                    spending("us-chase-sapphire-preferred", "Groceries", "groceries_where" => "Supermarkets")
    assert_operator spending("us-bofa-customized-cash", "Groceries", "groceries_where" => "Wholesale clubs"), :>,
                    spending("us-bofa-customized-cash", "Groceries", "groceries_where" => "Walmart or Target")
  end

  test "portal preferences change travel coverage without inventing direct rewards" do
    key = "us-chase-freedom-unlimited"
    direct = spending(key, "Travel", "travel_booking" => "Directly with airlines and hotels")
    assert_operator spending(key, "Travel", "travel_booking" => "I’m comfortable using a card’s travel portal"), :>, direct
    assert_equal direct, spending(key, "Travel", "travel_booking" => "No preference")
  end

  test "retailer follow-up is asked only when an Amazon card could enter the selection" do
    answers = @answers.merge("spending_priorities" => ["Online shopping"])
    assert_equal "foreign_purchases", Card.quiz_questions_for(answers).last[:key]
    prime = Card.find_by!(source_key: "us-prime-visa")
    prime.update!(catalogue_terms: prime.catalogue_terms.merge("editorial_credit_guidance" => { "band" => "good_to_excellent" }))
    assert_equal "shopping_where", Card.quiz_questions_for(answers).last[:key]
    assert_operator spending(prime.source_key, "Online shopping", "shopping_where" => "Amazon with Prime"), :>,
                    spending(prime.source_key, "Online shopping", "shopping_where" => "Other retailers")
    assert_equal spending("us-amex-blue-cash-everyday", "Online shopping", "shopping_where" => "Amazon with Prime"),
                 spending("us-amex-blue-cash-everyday", "Online shopping", "shopping_where" => "Amazon without Prime")
  end

  test "airline benefits ask the programme question and score named affinity" do
    answers = @answers.merge("priorities" => ["Useful perks"], "useful_benefits" => ["Airline or hotel benefits"])
    assert_equal "travel_programs", Card.quiz_questions_for(answers).last[:key]
    delta = fit("us-delta-gold", answers.merge("travel_programs" => ["Delta SkyMiles"]))
    assert_operator delta.features.fetch("program:Delta SkyMiles"), :>, 0
  end

  test "delivery coverage requires captured delivery terms" do
    key = "us-amex-gold"
    assert_operator spending(key, "Dining out", "dining_where" => "Directly with restaurants or cafés"), :>,
                    spending(key, "Dining out", "dining_where" => "Delivery apps")
    assert_equal spending("us-delta-gold", "Dining out", "dining_where" => "Directly with restaurants or cafés"),
                 spending("us-delta-gold", "Dining out", "dining_where" => "Delivery apps")
  end

  test "transport distinguishes gas EV charging and transit" do
    key = "us-amex-blue-cash-everyday"
    assert_operator spending(key, "Gas & transport", "transport_spending" => "Gas stations"), :>,
                    spending(key, "Gas & transport", "transport_spending" => "EV charging")
    assert_operator spending("us-amex-blue-cash-preferred", "Gas & transport", "transport_spending" => "Public transport or rideshares"), :>,
                    spending(key, "Gas & transport", "transport_spending" => "Public transport or rideshares")
  end

  test "streaming is not general entertainment and bills are not rent rewards" do
    key = "us-amex-blue-cash-preferred"
    assert_operator spending(key, "Entertainment & subscriptions", "entertainment_spending" => "Streaming subscriptions"), :>,
                    spending(key, "Entertainment & subscriptions", "entertainment_spending" => "Live events or cinemas")
    assert_equal 0, spending("us-wells-fargo-autograph", "Rent or bills", "bills_spending" => "Rent")
    assert_operator spending("us-wells-fargo-autograph", "Rent or bills", "bills_spending" => "Phone bills"), :>,
                    spending("us-wells-fargo-autograph", "Rent or bills", "bills_spending" => "Utilities")
  end

  test "category management changes fit but never invents quarterly category coverage" do
    key = "us-chase-freedom-flex"
    consistent = fit(key, "reward_management" => "Keep rewards consistent")
    flexible = fit(key, "reward_management" => "I’m happy to activate or choose categories")
    assert_operator flexible.score, :>, consistent.score
    assert_equal consistent.features["spend:Groceries"], flexible.features["spend:Groceries"]
    rise = fit("us-chase-freedom-rise")
    assert_equal rise.features["spend:Groceries"], rise.features["spend:Dining out"] * 4 / 2.5
  end

  test "first and next card management preferences affect fit" do
    key = "us-chase-freedom-unlimited"
    ordinary = fit(key)
    assert_operator fit(key, "first_card_management" => "Simple everyday rewards").score, :>, ordinary.score
    assert_operator fit(key, "first_card_management" => "No annual fee").score, :>, ordinary.score
    assert_operator fit(key, "first_card_management" => "Rewards focused on my main spending").features["spend:Dining out"], :>, ordinary.features["spend:Dining out"]
    assert_operator fit("us-chase-freedom-flex", "next_card_management" => "Consistent rewards without activation").score, :<, fit("us-chase-freedom-flex").score
    assert_operator fit(key, "next_card_management" => "One clear spending role").features["spend:Dining out"], :>, ordinary.features["spend:Dining out"]
  end

  test "foreign use frequency rewards only known fee-free coverage" do
    key = "us-capital-one-savor"
    assert_operator fit(key, "international_travel" => "Monthly or more").score, :>, fit(key, "international_travel" => "Once a year").score
    assert_operator fit(key, "foreign_purchases" => "Every month").score, :>, fit(key, "foreign_purchases" => "Never").score
    card = Card.find_by!(source_key: key)
    card.update!(foreign_transaction_fee: nil)
    assert_nil fit(key, "foreign_purchases" => "Every month").features["foreign"]
  end

  test "benefit rankings and named providers change fit without assuming unspecified credits" do
    extra = { "priorities" => ["Useful perks"], "useful_benefits" => ["Dining credits"] }
    uber = fit("us-amex-gold", extra.merge("dining_providers" => "Uber Eats"))
    assert uber.features.key?("benefit:Dining credits")
    assert_match /Uber Cash/, uber.reasons["benefit:Dining credits"]
    ["None", "Grubhub", "Other services"].each do |provider|
      refute fit("us-amex-gold", extra.merge("dining_providers" => provider)).features.key?("benefit:Dining credits")
    end
    credits = { "priorities" => ["Useful perks"], "useful_benefits" => ["Shopping or subscription credits"] }
    assert fit("us-amex-platinum", credits.merge("credit_providers" => "Streaming subscriptions")).features.key?("benefit:Shopping or subscription credits")
    refute fit("us-amex-platinum", credits.merge("credit_providers" => "Retail purchases")).features.key?("benefit:Shopping or subscription credits")
    refute fit("us-amex-platinum", credits.merge("credit_providers" => "Neither — I wouldn’t spend just to use a credit")).features.key?("benefit:Shopping or subscription credits")
    first = fit("us-capital-one-venture-x", "useful_benefits" => ["Airport lounge access", "Dining credits"])
    second = fit("us-capital-one-venture-x", "useful_benefits" => ["Dining credits", "Airport lounge access"])
    assert_operator first.features["benefit:Airport lounge access"], :>, second.features["benefit:Airport lounge access"]
  end

  test "ranked goals spending and monthly spend all affect scoring" do
    key = "us-capital-one-savor"
    assert_operator fit(key, "priorities" => ["Cashback", "Travel rewards"]).features["goal:Cashback"], :>,
                    fit(key, "priorities" => ["Travel rewards", "Cashback"]).features["goal:Cashback"]
    assert_operator fit(key, "spending_priorities" => ["Dining out", "Groceries"]).features["spend:Dining out"], :>,
                    fit(key, "spending_priorities" => ["Groceries", "Dining out"]).features["spend:Dining out"]
    assert_operator fit("us-amex-gold", "monthly_card_spend" => "Under $500").penalty, :>,
                    fit("us-amex-gold", "monthly_card_spend" => "$5,000+").penalty
  end

  test "automatic complexity uses experience while explicit maximum remains authoritative" do
    novice = QuizRecommendation.new(@answers.merge("stack_size" => "Recommend for me", "open_credit_cards" => "None right now"))
    experienced = QuizRecommendation.new(@answers.merge("stack_size" => "Recommend for me", "open_credit_cards" => "6+"))
    assert_operator novice.complexity_cost, :>, experienced.complexity_cost
    assert_equal QuizRecommendation.new(@answers.merge("open_credit_cards" => "6+")).complexity_cost,
                 QuizRecommendation.new(@answers.merge("open_credit_cards" => "None right now")).complexity_cost
  end

  test "automatic and multi-card answers return at least two when a suitable pair fits" do
    ["Recommend for me", "2", "3", "5"].each do |size|
      ["None right now", "3–5"].each do |owned|
        selected = QuizRecommendation.new(@answers.merge("stack_size" => size, "open_credit_cards" => owned, "annual_fee_budget" => "0")).cards
        assert_operator selected.size, :>=, 2
        assert_equal 0, selected.sum(&:annual_fee)
      end
    end
    assert_equal 1, QuizRecommendation.new(@answers.merge("stack_size" => "1", "open_credit_cards" => "3–5")).cards.size
  end

  test "minimum never overrides suitability or combined fee constraints" do
    Card.update_all(catalogue_status: "retired")
    first = Card.find_by!(source_key: "us-capital-one-savor")
    first.update!(catalogue_status: "published", annual_fee: 60)
    second = Card.find_by!(source_key: "us-amex-blue-cash-everyday")
    second.update!(catalogue_status: "published", annual_fee: 60)
    assert_equal 1, QuizRecommendation.new(@answers.merge("annual_fee_budget" => "100")).cards.size
    assert_equal 2, QuizRecommendation.new(@answers.merge("annual_fee_budget" => "120")).cards.size
    refute_empty QuizRecommendation.new(@answers.merge("credit_score" => "I don't know")).cards
    second.update!(catalogue_status: "retired")
    assert_equal [first.id], QuizRecommendation.new(@answers).cards.map(&:id)
  end

  test "selection respects combined fees and maximum and cards beyond the minimum contribute" do
    %w[0 95 100 300].each do |budget|
      recommendation = QuizRecommendation.new(@answers.merge("annual_fee_budget" => budget))
      selected = recommendation.cards
      assert_operator selected.size, :<=, 3
      assert_operator selected.sum(&:annual_fee), :<=, budget.to_d
      fits = recommendation.fits.select { |fit| selected.include?(fit.card) }
      if fits.size > 2
        fits.each { |fit| assert_operator recommendation.stack_score(fits), :>, recommendation.stack_score(fits - [fit]) }
      end
    end
    assert_equal 1, QuizRecommendation.new(@answers.merge("stack_size" => "1")).cards.size
  end

  test "two options remain available even when their rewards coverage overlaps" do
    Card.update_all(catalogue_status: "retired")
    source = Card.find_by!(source_key: "us-capital-one-savor")
    source.update!(catalogue_status: "published")
    duplicate = source.dup
    duplicate.source_key = "test-identical-savor"
    duplicate.name = "Duplicate coverage"
    duplicate.save!
    assert_equal [source.id, duplicate.id].sort, QuizRecommendation.new(@answers.merge("stack_size" => "5")).cards.map(&:id).sort
  end

  test "global selection beats an expensive individual card when two cheaper cards cover more" do
    Card.update_all(catalogue_status: "retired")
    base = Card.find_by!(source_key: "us-capital-one-savor")
    recipes = [
      ["expensive", 100, [{ "rate" => "2", "unit" => "cashback_percent", "category" => "Dining and groceries", "conditions" => "" }]],
      ["dining", 40, [{ "rate" => "3", "unit" => "cashback_percent", "category" => "Dining", "conditions" => "" }]],
      ["groceries", 40, [{ "rate" => "3", "unit" => "cashback_percent", "category" => "Groceries", "conditions" => "" }]]
    ]
    recipes.each do |key, fee, rules|
      card = base.dup
      card.assign_attributes(source_key: key, name: key, annual_fee: fee, catalogue_status: "published", catalogue_terms: base.catalogue_terms.merge("rewards" => rules))
      card.save!
    end
    recommendation = QuizRecommendation.new(@answers.merge("spending_priorities" => ["Dining out", "Groceries"], "stack_size" => "2"))
    assert_equal "expensive", recommendation.ranked_cards.first.source_key
    assert_equal %w[dining groceries], recommendation.cards.map(&:source_key).sort
  end

  test "saved results expose answer-specific reasons without dollar estimates" do
    recommendation = QuizRecommendation.new(@answers.merge("groceries_where" => "Supermarkets"))
    quiz = QuizResponse.create!(answers: recommendation.answers.to_json, top_card_ids: recommendation.cards.map(&:id).to_json, completed_at: Time.current)
    payload = ResultsStack.new(quiz).payload
    payload[:selected].each do |index|
      assert payload[:cards][index][:matchReasons].present?
      assert_equal false, payload[:cards][index][:estimatesAvailable]
    end
  end
end
