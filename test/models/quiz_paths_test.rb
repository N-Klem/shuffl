ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizPathsTest < ActiveSupport::TestCase
  test "every spending and benefits branch has ten unique questions" do
    Card::GOAL_QUESTIONS.each_key do |goal|
      Card::QUESTION_POOL.fetch("spending_priorities")[:options].each do |spending|
        Card::FOLLOW_UP_QUESTIONS.fetch("useful_benefits")[:options].each do |benefit|
          answers = { "priorities" => [goal], "spending_priorities" => [spending], "useful_benefits" => [benefit] }
          questions = Card.quiz_questions_for(answers)
          assert_equal 10, questions.size
          assert_equal 10, questions.map { |q| q[:key] }.uniq.size
          refute questions.any? { |q| %w[pays_in_full signup_bonus_interest].include?(q[:key]) }
        end
      end
    end
  end

  test "student first card wording respects the chosen goal" do
    answers = { "priorities" => ["Building credit"], "open_credit_cards" => "None right now", "employment_status" => "Student", "spending_priorities" => ["Online shopping"] }
    questions = Card.quiz_questions_for(answers)
    assert_match /As a student/, questions[8][:prompt]
    assert_equal "foreign_purchases", questions[9][:key]
    answers["priorities"] = ["Travel rewards"]
    assert_equal %w[travel_programs international_travel], Card.quiz_questions_for(answers).last(2).map { |q| q[:key] }
  end
end
