ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class RewardsCalculatorTest < ActiveSupport::TestCase
  setup do
    @snapshot = JSON.parse(Rails.root.join("data/real_cards/catalogue.json").read).fetch("cards")
  end

  def card(key)
    row = @snapshot.find { |candidate| candidate["source_key"] == "us-#{key}" }
    Card.new(id: row["shortlist_position"], source_key: row["source_key"], name: row["name"],
      country: "US", currency: "USD", catalogue_status: "published", catalogue_terms: row["research"].deep_dup)
  end

  def estimate(cards, amounts, confirmed: true)
    RewardsCalculator.new(cards: Array(cards), amounts: amounts, confirmed: confirmed).call
  end

  test "spending and repayment confirmation are required even for flat cashback" do
    result = estimate(card("wells-fargo-active-cash"), [1000, 0, 0, 0, 0, 0], confirmed: false)
    assert_equal "confirmation_required", result[:status]
    assert_nil result[:gross]
    assert_empty result[:allocation]
    assert_equal 0, result[:fees]
  end

  test "all nine reviewed profiles match the portable research" do
    assert_equal 9, RewardsCalculator::PROFILES.size
    RewardsCalculator::PROFILES.each_key do |key|
      assert_nil RewardsCalculator.unavailable_reason(card(key.delete_prefix("us-"))), key
    end
  end

  test "flat cashback and decimal dollars are calculated without early rounding" do
    result = estimate(card("wells-fargo-active-cash"), [1000.25, 0, 0, 0, 0, 0])
    assert_equal "available", result[:status]
    assert_equal 240.06, result[:gross]
    assert_equal result[:gross], result[:net]
  end

  test "capped supermarkets fall back to base and ongoing fee ignores first year waiver" do
    bcp = card("amex-blue-cash-preferred")
    assert_equal 360, estimate(bcp, [0, 0, 500, 0, 0, 0])[:gross]
    result = estimate(bcp, [0, 0, 1000, 0, 0, 0])
    assert_equal 420, result[:gross] # $6,000 at 6%, $6,000 at 1%
    assert_equal 95, result[:fees]
    assert_equal 325, result[:net]
    assert_equal [6000, 6000], result[:allocation].map { |row| row[:annualSpend] }
  end

  test "cap overflow goes to the next card without double counting" do
    bcp, flat = card("amex-blue-cash-preferred"), card("wells-fargo-active-cash")
    result = estimate([bcp, flat, bcp], [0, 0, 1000, 0, 0, 0])
    assert_equal 480, result[:gross]
    assert_equal 385, result[:net]
    assert_equal 12000, result[:allocation].sum { |row| row[:annualSpend] }
    assert_equal [360, 120], result[:contributions].map { |row| row[:gross] }
  end

  test "Blue Cash Everyday caps are independent and uncategorized online spending earns base" do
    result = estimate(card("amex-blue-cash-everyday"), [0, 0, 1000, 1000, 0, 1000])
    assert_equal 600, result[:gross] # 240 supermarkets + 240 gas + 120 other
  end

  test "portal bonuses and introductory dining are excluded from ongoing scenario" do
    result = estimate(card("chase-freedom-unlimited"), [100, 100, 0, 0, 0, 0])
    assert_equal 54, result[:gross] # 3% dining, 1.5% direct travel
    assert_equal 18, estimate(card("chase-freedom-rise"), [100, 0, 0, 0, 0, 0])[:gross]
  end

  test "bonus category exclusions use the other bucket and no conditional credits are added" do
    result = estimate(card("capital-one-savor"), [100, 0, 100, 0, 100, 100])
    assert_equal 120, result[:gross] # eligible dining/grocery/streaming + excluded grocery at base
    assert_equal 0, estimate(card("amex-blue-cash-preferred"), [0] * 6)[:gross]
    assert_equal(-95, estimate(card("amex-blue-cash-preferred"), [0] * 6)[:net])
  end

  test "purchase and repayment component is included once" do
    assert_equal 240, estimate(card("citi-double-cash"), [1000, 0, 0, 0, 0, 0])[:gross]
  end

  test "unmodeled calendars shared caps membership and points are unavailable not zero" do
    %w[chase-freedom-flex discover-it-cash-back discover-it-student bofa-customized-cash prime-visa chase-sapphire-preferred].each do |key|
      result = estimate(card(key), [1000, 0, 0, 0, 0, 0])
      assert_equal "unavailable", result[:status], key
      assert_nil result[:gross]
      assert_nil result[:net]
      assert_nil result[:contributions].first[:gross]
      assert result[:contributions].first[:reason].present?
      assert_equal "unavailable", estimate(card(key), [0] * 6, confirmed: false)[:status]
    end
  end

  test "mixed stack reports supported portion and all fees but no total value" do
    flat, points = card("wells-fargo-active-cash"), card("chase-sapphire-preferred")
    result = estimate([flat, points], [1000, 0, 0, 0, 0, 0])
    assert_equal "partial", result[:status]
    assert_equal 240, result[:gross]
    assert_equal 95, result[:fees]
    assert_nil result[:net]
    assert_nil result[:contributions].last[:gross]
    assert_equal [flat.id], result[:allocation].map { |row| row[:cardId] }.uniq
  end

  test "unknown annual or monthly fees do not become zero" do
    flat = card("wells-fargo-active-cash")
    flat.catalogue_terms["fees"]["annual"] = nil
    result = estimate(flat, [1000, 0, 0, 0, 0, 0])
    assert_equal 240, result[:gross]
    assert_nil result[:fees]
    assert_nil result[:net]
    flat.catalogue_terms["fees"]["annual"] = "0"
    flat.catalogue_terms["fees"]["monthly_applicability"] = "unknown"
    assert_nil estimate(flat, [0] * 6)[:fees]
    flat.catalogue_terms["fees"]["monthly"] = "5"
    assert_equal 60, estimate(flat, [0] * 6)[:fees]
  end

  test "changed terms and retired records cannot reuse a reviewed rate" do
    flat = card("wells-fargo-active-cash")
    flat.catalogue_terms["rewards"][0]["conditions"] = "A new cap applies"
    assert_equal "unavailable", estimate(flat, [1000, 0, 0, 0, 0, 0])[:status]
    flat = card("wells-fargo-active-cash")
    flat.catalogue_status = "retired"
    assert_nil estimate(flat, [1000, 0, 0, 0, 0, 0])[:gross]
  end

  test "invalid spending is rejected and zero spending is distinct from unknown" do
    [nil, {}, [], [1] * 5, [-1] * 6, [Float::NAN] * 6, [Float::INFINITY] * 6, ["100"] * 6, [1_000_001] * 6].each do |amounts|
      refute RewardsCalculator.valid_amounts?(amounts)
    end
    result = estimate(card("wells-fargo-active-cash"), [0] * 6)
    assert_equal "available", result[:status]
    assert_equal 0, result[:gross]
    assert_empty result[:allocation]
    assert_equal "unavailable", estimate([], [0] * 6)[:status]
  end
end
