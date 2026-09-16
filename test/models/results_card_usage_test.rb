ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class ResultsCardUsageTest < ActiveSupport::TestCase
  def card(key)
    row = JSON.parse(Rails.root.join("data/real_cards/catalogue.json").read)["cards"].find { |c| c["source_key"] == "us-#{key}" }
    Card.new(source_key: row["source_key"], name: row["name"], catalogue_status: "published", catalogue_terms: row["research"])
  end

  def uses(key, answers = {})
    QuizCardFit.new(card(key), answers).recommended_uses
  end

  test "ranked spending gets a concrete source-backed use and native earning rate" do
    use = uses("amex-gold", "spending_priorities" => ["Dining out", "Groceries"]).first
    assert_equal "Restaurants worldwide", use["use_for"]
    assert_equal "4", use["rate"]
    assert_equal "points_per_USD", use["unit"]
    assert_match "50,000", use["conditions"]
  end

  test "flight-specific earning never becomes general travel" do
    use = uses("amex-platinum", "spending_priorities" => ["Travel"]).first
    assert_equal "Direct airline or Amex Travel flights", use["use_for"]
    assert_match "500,000", use["conditions"]
  end

  test "flat cards show everyday rewards instead of leading with portal promotions" do
    use = uses("capital-one-venture").first
    assert_equal "Everyday purchases", use["use_for"]
    assert_equal "2", use["rate"]
  end

  test "additional genuine roles are available when another card covers the first category" do
    options = uses("wells-fargo-autograph", "spending_priorities" => ["Travel"])
    assert_equal "Travel", options.first["use_key"]
    dining = options.find { |use| use["use_key"] == "Dining out" }
    assert_equal "Restaurants", dining["use_for"]
    assert_equal "3", dining["rate"]
  end

  test "temporary and rotating categories are not suggested as permanent coverage" do
    assert_equal ["1.5"], uses("chase-freedom-rise").map { |use| use["rate"] }.uniq
    assert_equal ["1"], uses("discover-it-cash-back").map { |use| use["rate"] }.uniq
  end

  test "nonreward and retired cards do not acquire invented usage rates" do
    assert_empty uses("capital-one-platinum")
    retired = card("amex-gold")
    retired.catalogue_status = "retired"
    assert_empty QuizCardFit.new(retired, {}).recommended_uses
  end
end
