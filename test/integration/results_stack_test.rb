ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class ResultsStackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @card = Card.create!(name: "Dining Plus", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 20, reward_rate: 3)
    @other = Card.create!(name: "Other test card", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 0, reward_rate: 1)
    @quiz = QuizResponse.create!(completed_at: Time.current, answers: '{"monthly_card_spend":"$1,000–$2,500"}', top_card_ids: [@card.id].to_json)
    @user = User.create!(first_name: "Results", email: "results-test@example.com", password: "password123")
  end

  test "results retain recommendations and initialize spending from quiz" do
    get quiz_response_path(@quiz)
    assert_response :success
    assert_select '[data-controller="results"]'
    assert_select 'nav.site-nav'
    payload = ResultsStack.new(@quiz).payload
    assert_equal @card.id, payload[:cards][payload[:selected].first][:id]
    assert_equal 1750, payload[:amounts].sum
    assert_equal [0.0] * 6, payload[:cards].find { |card| card[:id] == @other.id }[:rates]
  end

  test "anonymous save requires login and creates no wallet items" do
    assert_no_difference "WalletItem.count" do
      post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@card.id] }, as: :json
    end
    assert_response :unauthorized
    assert_equal new_user_session_path, response.parsed_body["sign_in_url"]
  end

  test "save adds the whole stack only to current user and is idempotent" do
    sign_in @user
    2.times do
      post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@card.id, @other.id] }, as: :json
      assert_response :success
    end
    assert_equal [@card.id, @other.id].sort, @user.cards.pluck(:id).sort
    assert_equal wallet_items_path, response.parsed_body["wallet_url"]
  end

  test "invalid stack is rejected atomically" do
    sign_in @user
    assert_no_difference "WalletItem.count" do
      post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@card.id, "999999999"] }, as: :json
    end
    assert_response :unprocessable_entity
  end
end
