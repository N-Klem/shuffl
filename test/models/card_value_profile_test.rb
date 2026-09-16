ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class CardValueProfileTest < ActiveSupport::TestCase
  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
  end

  test "Platinum presents credit building and costs without empty reward or offer metrics" do
    card = Card.find_by!(source_key: "us-capital-one-platinum")
    profile = card.value_profile
    assert_equal "credit", profile[:kind]
    assert_equal "Build your credit", profile[:title]
    assert_equal "$0", profile[:value]
    assert_equal "Annual fee", profile[:label]
    assert_equal false, profile[:estimateSupported]
    assert_includes profile[:detail], "does not earn purchase rewards"
    assert_nil card.displayed_welcome_offer
    assert_nil card.results_data[:welcomeOffer]
    assert_equal "credit", BrowseCatalogue.new.payload[:cards].find { |row| row[:id] == card.id.to_s }[:valueProfile][:kind]
  end

  test "missing research does not become a no rewards claim" do
    card = Card.find_by!(source_key: "us-capital-one-platinum")
    card.catalogue_terms = card.catalogue_terms.except("rewards_status", "welcome_offer_status")
    card.welcome_bonus = nil
    assert_equal "features", card.value_profile[:kind]
    refute_includes card.value_profile[:detail], "does not earn"
    assert_nil card.displayed_welcome_offer
  end

  test "points and rotating cashback keep units and qualifying conditions without dollar estimates" do
    points = Card.find_by!(source_key: "us-chase-sapphire-preferred")
    assert_equal "travel", points.value_profile[:kind]
    assert_includes points.value_profile[:value], "points / $1"
    refute points.value_profile[:estimateSupported]
    rotating = Card.find_by!(source_key: "us-discover-it-cash-back")
    assert_equal "5% cashback", rotating.value_profile[:value]
    assert_includes rotating.value_profile[:conditions], "Activation required"
    refute rotating.value_profile[:estimateSupported]
  end

  test "supported cashback keeps calculator and promotional rates do not become headline earnings" do
    rise = Card.find_by!(source_key: "us-chase-freedom-rise")
    assert_equal "1.5% cashback", rise.value_profile[:value]
    assert rise.value_profile[:estimateSupported]
    assert rise.displayed_welcome_offer.present?
    Card.available.each do |card|
      assert card.value_profile[:value].present?, card.name
      assert card.value_profile[:label].present?, card.name
      refute_match(/unavailable|not captured/i, card.value_profile.to_json, card.name)
    end
  end
end
