ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizFlowTest < ActionDispatch::IntegrationTest
  test "all questions validate, preserve answers on back, reject stale posts, and complete" do
    card = Card.create!(name: "Quiz test card", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 0, reward_rate: 1, best_for: "Cashback", credit_score_min: 600)
    get new_quiz_response_path
    assert_response :success
    assert_select "[role='progressbar'][aria-valuemax='16']"
    assert_select ".quiz-bubble", count: 16

    post quiz_responses_path, params: { step: 0, answer: "invalid answer" }
    assert_response :unprocessable_entity
    assert_select "input[name='step'][value='0']"

    first = Card::QUIZ_QUESTIONS.first
    post quiz_responses_path, params: { step: 0, answer: first[:options].first }
    assert_response :see_other
    follow_redirect!
    assert_select "input[name='step'][value='1']"

    post quiz_responses_path, params: { step: 0, answer: first[:options].last }
    follow_redirect!
    assert_select "input[name='step'][value='1']"

    get new_quiz_response_path(step: 0)
    assert_select "input[checked][value=?]", first[:options].first

    assert_difference "QuizResponse.count", 1 do
      Card::QUIZ_QUESTIONS.each_with_index do |question, index|
        post quiz_responses_path, params: { step: index, answer: question[:options].last }
        assert_response :see_other
        follow_redirect!
        assert_response :success
      end
    end
    assert_select "h2", text: card.name
    saved = JSON.parse(QuizResponse.order(:id).last.answers)
    assert_equal 16, saved.size
    assert_equal first[:options].last, saved[first[:key]]

    get new_quiz_response_path
    assert_select "input[name='step'][value='0']"
  end
end
