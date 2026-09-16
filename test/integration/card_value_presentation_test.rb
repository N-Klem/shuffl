ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class CardValuePresentationTest < ActionDispatch::IntegrationTest
  test "Platinum detail focuses on credit building and omits empty welcome and reward rows" do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    card = Card.find_by!(source_key: "us-capital-one-platinum")
    get card_path(card)
    assert_response :success
    assert_select ".lede", "Build your credit"
    assert_select ".detail-figure", "$0"
    assert_select ".detail-figure-label", "Annual fee"
    assert_select ".detail-facts .key", text: "Welcome offer", count: 0
    assert_includes response.body, "does not earn purchase rewards"
    refute_match(/unavailable|not captured|no welcome bonus listed/i, response.body)
  end
end
