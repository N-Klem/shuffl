ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class WalletDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(first_name: "Wallet", email: "wallet-test@example.com", password: "password123")
    @other = User.create!(first_name: "Other", email: "wallet-other@example.com", password: "password123")
    @card = Card.create!(name: "Wallet test", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 20, reward_rate: 2)
    @replacement = Card.create!(name: "Replacement", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 0, reward_rate: 1)
    @item = @user.wallet_items.create!(card: @card)
    sign_in @user
  end

  test "ledger renders with shared navbar and real wallet payload" do
    get wallet_items_path
    assert_response :success
    assert_select 'nav.site-nav', 1
    assert_select '[data-controller="wallet"]', 1
    assert_equal false, WalletDashboard.new(@user).payload[:cards].first[:owned]
  end

  test "ownership payment and bonus details persist" do
    patch wallet_item_path(@item), params: { wallet_item: { status: "owned", opened_on: "2026-09-12", bonus_deadline: "2026-12-12", bonus_target: 3000, bonus_spend: 1200, statement_balance: 800, payment_due_on: "2026-10-01" } }, as: :json
    assert_response :success
    assert_equal "owned", @item.reload.status
    assert_equal 1200, @item.bonus_spend
    patch wallet_item_path(@item), params: { wallet_item: { paid: true } }, as: :json
    assert_response :success
    assert @item.reload.paid
  end

  test "planned swaps preserve wallet identity but owned swaps are rejected" do
    patch wallet_item_path(@item), params: { wallet_item: { card_id: @replacement.id } }, as: :json
    assert_response :success
    assert_equal @replacement.id, @item.reload.card_id
    @item.update!(status: "owned")
    patch wallet_item_path(@item), params: { wallet_item: { card_id: @card.id } }, as: :json
    assert_response :unprocessable_entity
    assert_equal @replacement.id, @item.reload.card_id
  end

  test "another account cannot update wallet items" do
    item = @other.wallet_items.create!(card: @card)
    patch wallet_item_path(item), params: { wallet_item: { paid: true } }, as: :json
    assert_response :not_found
    assert_not item.reload.paid
  end

  test "invalid amounts dates and duplicate swaps do not overwrite state" do
    patch wallet_item_path(@item), params: { wallet_item: { bonus_spend: -1 } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, @item.reload.bonus_spend
    patch wallet_item_path(@item), params: { wallet_item: { opened_on: "2026-09-12", bonus_deadline: "2026-09-01" } }, as: :json
    assert_response :unprocessable_entity
    @user.wallet_items.create!(card: @replacement)
    patch wallet_item_path(@item), params: { wallet_item: { card_id: @replacement.id } }, as: :json
    assert_response :unprocessable_entity
    assert_equal @card.id, @item.reload.card_id
  end

  test "spending and notification preferences persist and validate" do
    patch preferences_wallet_items_path, params: { preferences: { amounts: [100,200,300,400,500,600], notifications: true } }, as: :json
    assert_response :success
    assert_equal [100,200,300,400,500,600], response.parsed_body["amounts"]
    assert_equal true, response.parsed_body["notifications"]
    patch preferences_wallet_items_path, params: { preferences: { amounts: [-1] } }, as: :json
    assert_response :unprocessable_entity
    assert_equal 6, @user.reload.wallet_preferences["amounts"].size
  end
end
