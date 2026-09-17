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

  test "results retain recommendations without inventing category spending" do
    get quiz_response_path(@quiz)
    assert_response :success
    assert_select '[data-controller~="results"]'
    assert_select 'nav.site-nav'
    payload = ResultsStack.new(@quiz).payload
    assert_equal @card.id, payload[:cards][payload[:selected].first][:id]
    refute payload.key?(:amounts)
    refute payload.key?(:spendingPlan)
    assert_select '#confirm-spending', count: 0
    assert_select '#spend', count: 0
    assert_select '#spending-guide', count: 0
    assert_select 'aside.summary', count: 0
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

  test "selected cards survive failed sign in and appear on the wallet immediately" do
    @user.wallet_items.create!(card: @card, status: "owned")
    post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@card.id, @other.id] }, as: :json
    get new_user_session_path
    assert_select '.stack-caption span', text: '2 cards'
    post user_session_path, params: { user: { email: @user.email, password: "wrong" } }
    assert_response :unprocessable_entity
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_redirected_to wallet_items_path
    follow_redirect!
    assert_response :success
    assert_wallet_cards @user, [@card.id, @other.id]
    assert_equal "owned", @user.wallet_items.find_by!(card: @card).status
    get wallet_items_path
    assert_equal 2, @user.wallet_items.count
  end

  test "selected cards survive switching to signup and invalid registration" do
    post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@other.id] }, as: :json
    get new_user_session_path
    get new_user_registration_path
    attributes = { first_name: "New", email: "new-wallet@example.com", password: "password123", password_confirmation: "mismatch" }
    post user_registration_path, params: { user: attributes }
    assert_response :unprocessable_entity
    assert_no_difference "WalletItem.count" do
      get new_user_registration_path
    end
    post user_registration_path, params: { user: attributes.merge(password_confirmation: "password123") }
    assert_redirected_to wallet_items_path
    follow_redirect!
    user = User.find_by!(email: attributes[:email])
    assert_wallet_cards user, [@other.id]
    assert_equal "planned", user.wallet_items.first.status
    assert_empty @user.wallet_items

    # A saved and subsequently removed pick must not be replayed on later logins.
    user.wallet_items.destroy_all
    delete destroy_user_session_path
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_empty user.wallet_items
  end

  test "invalid anonymous selections never become pending wallet cards" do
    post save_stack_wallet_items_path, params: { quiz_response_id: @quiz.id, card_ids: [@card.id, "999999999"] }, as: :json
    assert_response :unprocessable_entity
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_empty @user.wallet_items
  end

  private

  def assert_wallet_cards(user, ids)
    assert_equal ids.sort, user.cards.pluck(:id).sort
    element = css_select('[data-wallet-payload-value]').first
    payload = JSON.parse(element['data-wallet-payload-value'])
    assert_equal ids.sort, payload['cards'].map { |card| card['cardId'] }.sort
  end
end
