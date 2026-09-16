ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class SpendingPlanTest < ActiveSupport::TestCase
  def card(key)
    row = JSON.parse(Rails.root.join("data/real_cards/catalogue.json").read)["cards"].find { |c| c["source_key"] == "us-#{key}" }
    Card.new(id: row["shortlist_position"], source_key: row["source_key"], name: row["name"], country: "US",
      currency: "USD", catalogue_status: "published", catalogue_terms: row["research"].deep_dup)
  end

  def plan(cards, amounts = [300, 200, 500, 100, 50, 850], confirmed: true, programmes: [])
    SpendingPlan.new(cards: Array(cards), amounts: amounts, confirmed: confirmed, programmes: programmes).call
  end

  test "guide is useful before confirmation but never assumes amounts or earnings" do
    result = plan(card("chase-sapphire-preferred"), confirmed: false)
    assert_equal "confirmation_required", result[:status]
    assert_empty result[:totals]
    assert_empty result[:allocation]
    assert_nil result[:categories].first[:monthlySpend]
    assert_equal 3, result[:categories].first[:options].first[:rate]
    assert_equal "Chase Ultimate Rewards", result[:categories].first[:options].first[:label]
  end

  test "all configured profiles match recorded terms and edits fail closed" do
    SpendingPlan::POINTS.each_key do |key|
      c = card(key.delete_prefix("us-"))
      assert SpendingPlan.profile(c), key
      c.catalogue_terms["rewards"][0]["conditions"] += " changed"
      assert_nil SpendingPlan.profile(c), key
    end
    assert_nil SpendingPlan.profile(card("discover-it-cash-back"))
    assert_nil SpendingPlan.profile(card("prime-visa"))
  end

  test "cashback cap overflow moves to another card and every dollar is counted once" do
    bcp, flat = card("amex-blue-cash-preferred"), card("wells-fargo-active-cash")
    result = plan([bcp, flat, bcp], [0, 0, 1000, 0, 0, 0])
    assert_equal "ready", result[:status]
    assert_equal 480, result[:totals].first[:earned]
    assert_equal 385, result[:netCashback]
    assert_equal [bcp.id, flat.id], result[:allocation].map { |row| row[:cardId] }
    assert_equal 12000, result[:allocation].sum { |row| row[:annualSpend] }
  end

  test "points and cashback require a programme choice and cannot be compared by rate" do
    cards = [card("amex-gold"), card("wells-fargo-active-cash")]
    result = plan(cards, [500, 0, 0, 0, 0, 500])
    assert_equal "choices_required", result[:status]
    assert_empty result[:totals]
    assert_empty result[:allocation]
    result = plan(cards, [500, 0, 0, 0, 0, 500], programmes: ["amex", "", "", "", "", "cashback"])
    assert_equal "ready", result[:status]
    assert_equal [24000, 120], result[:totals].map { |row| row[:earned] }
    assert_equal ["points", "cashback"], result[:totals].map { |row| row[:unit] }
    assert_equal 12000, result[:allocation].sum { |row| row[:annualSpend] }
    assert_nil result[:netCashback]
    assert_equal 325, result[:fees]
  end

  test "Gold uses independent caps in native points and no credits or bonuses" do
    result = plan(card("amex-gold"), [5000, 0, 3000, 0, 0, 0])
    assert_equal 321000, result[:totals].first[:earned] # 200k + 10k dining; 100k + 11k supermarkets
    assert_equal 325, result[:fees]
    assert_nil result[:netCashback]
    assert_equal 96000, result[:allocation].sum { |row| row[:annualSpend] }
  end

  test "broad travel and in-store groceries do not inherit narrower bonus rates" do
    gold = plan(card("amex-gold"), [0, 100, 0, 0, 0, 0])
    assert_equal 1200, gold[:totals].first[:earned]
    assert_match "base rate", gold[:allocation].first[:reason]
    chase = plan(card("chase-sapphire-preferred"), [0, 0, 100, 0, 0, 0])
    assert_equal 1200, chase[:totals].first[:earned]
  end

  test "same programme cards do not duplicate spend or require unnecessary choices" do
    result = plan([card("capital-one-venture"), card("capital-one-venture-x")], [1000, 0, 0, 0, 0, 0])
    assert_equal "ready", result[:status]
    assert_equal 24000, result[:totals].first[:earned]
    assert_equal "miles", result[:totals].first[:unit]
    assert_equal 490, result[:fees]
    assert_equal 12000, result[:allocation].sum { |row| row[:annualSpend] }
  end

  test "retired or changed cards and stale choices cannot generate numbers" do
    c = card("capital-one-venture")
    result = plan(c, programmes: ["unknown"] * 6)
    assert_equal "choices_required", result[:status]
    assert_empty result[:totals]
    c.catalogue_status = "retired"
    assert_empty plan(c)[:totals]
    assert_empty plan(card("amex-gold"), [-1] * 6)[:totals]
  end
end
