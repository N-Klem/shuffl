ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"
class BrowseCatalogueTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup do
    @user=User.create!(first_name: "Browse",email: "browse-test@example.com",password: "password123")
    @card=Card.create!(name: "Test",issuer: "Test",network: "Visa",card_type: "Credit",annual_fee: 0,reward_rate: 1)
  end
  test "public catalogue and stacks share browser" do
    get cards_path
    assert_response :success
    assert_select '[data-controller="browse"]'
    get stacks_path
    assert_redirected_to cards_path(tab: "stacks")
  end
  test "saving requires authentication" do
    post save_browse_wallet_items_path,params: {card_ids:[@card.id]},as: :json
    assert_response :unauthorized
  end
  test "save is scoped idempotent and preserves owned cards" do
    sign_in @user
    item=@user.wallet_items.create!(card:@card,status:"owned")
    2.times { post save_browse_wallet_items_path,params:{card_ids:[@card.id]},as: :json; assert_response :success }
    assert_equal 1,@user.wallet_items.count
    assert_equal "owned",item.reload.status
    assert_no_difference 'WalletItem.count' do
      post save_browse_wallet_items_path,params:{card_ids:[@card.id,'9999999']},as: :json
    end
    assert_response :unprocessable_entity
  end
end
