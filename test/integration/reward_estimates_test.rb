ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class RewardEstimatesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    @card = Card.find_by!(source_key: "us-wells-fargo-active-cash")
    @points = Card.find_by!(source_key: "us-chase-sapphire-preferred")
    @amounts = [1000, 0, 0, 0, 0, 0]
    @user = User.create!(first_name: "Cashback", email: "cashback-calculator@example.com", password: "password123")
  end

  test "anonymous calculation uses server terms and does not write records" do
    before = [WalletItem.count, QuizResponse.count, Card.count]
    post reward_estimates_path, params: { card_ids: [@card.id, @card.id], amounts: @amounts,
      confirmed: true, rates: [100], fees: -1000 }, as: :json
    assert_response :success
    assert_equal 240, response.parsed_body["net"]
    assert_equal before, [WalletItem.count, QuizResponse.count, Card.count]
  end

  test "native rewards endpoint returns programme totals without dollar conversion" do
    post reward_estimates_path, params: { card_ids: [@points.id], amounts: @amounts,
      confirmed: true, plan: true, programmes: [""] * 6 }, as: :json
    assert_response :success
    assert_equal "ready", response.parsed_body["status"]
    assert_equal 36000, response.parsed_body["totals"].first["earned"]
    assert_nil response.parsed_body["netCashback"]
    post reward_estimates_path, params: { card_ids: [@points.id], amounts: @amounts,
      plan: true, programmes: { malicious: "cashback" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "wallet preserves programme choices and excludes planned points cards" do
    @user.wallet_items.create!(card: @card, status: "owned")
    @user.wallet_items.create!(card: @points, status: "planned")
    sign_in @user
    patch preferences_wallet_items_path, params: { preferences: { amounts: @amounts,
      spending_confirmed: true, reward_programmes: ["cashback"] * 6 } }, as: :json
    assert_response :success
    assert_equal [@card.id], response.parsed_body.dig("spendingPlan", "coveredCardIds")
    assert_equal 240, response.parsed_body.dig("spendingPlan", "netCashback")
    patch preferences_wallet_items_path, params: { preferences: { notifications: true } }, as: :json
    assert_equal ["cashback"] * 6, @user.reload.wallet_preferences["reward_programmes"]
  end

  test "invalid and missing inputs cannot produce an estimate" do
    [{}, { card_ids: [@card.id], amounts: ["NaN"] * 6 },
     { card_ids: [@card.id], amounts: { bad: 10 } },
     { card_ids: ["missing"], amounts: @amounts },
     { card_ids: [999999999], amounts: @amounts }].each do |input|
      post reward_estimates_path, params: input, as: :json
      assert_response :unprocessable_entity
    end
    post reward_estimates_path, params: { card_ids: [@card.id], amounts: @amounts }, as: :json
    assert_response :success
    assert_equal "confirmation_required", response.parsed_body["status"]
    assert_nil response.parsed_body["gross"]
  end

  test "wallet requires new confirmation and allocates owned cards only" do
    @user.wallet_items.create!(card: @card, status: "owned")
    planned = @user.wallet_items.create!(card: @points, status: "planned")
    @user.update!(wallet_preferences: { amounts: @amounts })
    assert_nil WalletDashboard.new(@user).payload[:estimate][:gross]
    sign_in @user
    patch preferences_wallet_items_path, params: { preferences: { amounts: @amounts, spending_confirmed: true } }, as: :json
    assert_response :success
    assert_equal 240, response.parsed_body.dig("estimate", "net")
    assert_equal true, response.parsed_body["spendingConfirmed"]
    assert_equal [@card.id], response.parsed_body.dig("estimate", "contributions").map { |row| row["cardId"] }
    patch wallet_item_path(planned), params: { wallet_item: { status: "owned" } }, as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("estimate", "gross")
    assert_equal false, response.parsed_body["spendingConfirmed"]
  end

  test "preferences cannot confirm historical amounts without submitting a new plan" do
    @user.update!(wallet_preferences: { amounts: @amounts })
    sign_in @user
    patch preferences_wallet_items_path, params: { preferences: { spending_confirmed: true } }, as: :json
    assert_response :success
    assert_equal false, response.parsed_body["spendingConfirmed"]
    assert_equal @amounts, @user.reload.wallet_preferences["amounts"]
  end
end
