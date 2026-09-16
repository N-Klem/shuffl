ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizEligibilityTest < ActiveSupport::TestCase
  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
  end

  def keys(score, **extras)
    Card.ranked_for({ "credit_score" => score, "employment_status" => "Employed full-time" }.merge(extras.stringify_keys)).map(&:source_key)
  end

  test "no history and damaged credit are separate profiles" do
    assert_equal ["us-chase-freedom-rise"], keys("No credit history")
    assert_empty keys("Building (300–579)")
    assert_empty keys("I don't know")
    assert_empty keys(nil)
    assert_equal ["us-capital-one-platinum"], keys("Fair (580–669)")
  end

  test "student status is an explicit requirement rather than a suitability tag" do
    student = keys("No credit history", employment_status: "Student")
    assert_includes student, "us-chase-freedom-rise"
    assert_includes student, "us-discover-it-student"
    refute_includes student, "us-bofa-student-travel"
    refute_includes student, "us-capital-one-savor-student"
    assert_includes keys("Fair (580–669)", employment_status: "Student"), "us-capital-one-savor-student"
    refute_includes keys("Excellent (740+)"), "us-bofa-student-travel"
  end

  test "excellent-only and unknown guidance cannot pass through strong rewards scores" do
    refute_includes keys("Good (670–739)", priorities: ["Travel rewards", "Useful perks"]), "us-capital-one-venture-x"
    assert_includes keys("Excellent (740+)"), "us-capital-one-venture-x"
    refute_includes keys("Excellent (740+)"), "us-chase-sapphire-reserve"
    refute_includes keys("Excellent (740+)"), "us-chase-freedom-rise"
  end

  test "named programme and credit profile must both fit" do
    refute_includes keys("Fair (580–669)", travel_programs: ["Delta SkyMiles"]), "us-delta-gold"
    refute_includes keys("Good (670–739)"), "us-delta-gold"
    assert_includes keys("Good (670–739)", travel_programs: ["Delta SkyMiles"]), "us-delta-gold"
    refute_includes keys("Excellent (740+)", travel_programs: ["United MileagePlus"]), "us-united-explorer"
  end

  test "results swaps use the filtered catalogue while preserving saved recommendations" do
    rise = Card.find_by!(source_key: "us-chase-freedom-rise")
    quiz = QuizResponse.create!(answers: { credit_score: "No credit history", employment_status: "Employed full-time" }.to_json,
                                top_card_ids: [rise.id].to_json, completed_at: Time.current)
    data = ResultsStack.new(quiz).payload
    assert_equal [rise.id], data[:cards].map { |card| card[:id] }
    assert_equal [0], data[:selected]
    rise.update!(catalogue_status: "retired")
    data = ResultsStack.new(quiz).payload
    assert_equal [rise.id], data[:cards].map { |card| card[:id] }
    assert data[:cards].first[:retired]
  end

  test "Prime membership is required even if credit guidance is later supplied" do
    card = Card.find_by!(source_key: "us-prime-visa")
    card.update!(catalogue_terms: card.catalogue_terms.merge("editorial_credit_guidance" => { "band" => "good_to_excellent" }))
    refute_includes keys("Good (670–739)"), card.source_key
    refute_includes keys("Good (670–739)", shopping_where: "Amazon without Prime"), card.source_key
    assert_includes keys("Good (670–739)", shopping_where: "Amazon with Prime"), card.source_key
  end
end
