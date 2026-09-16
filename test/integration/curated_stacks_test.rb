ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class CuratedStacksTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    Stack.import_demo!
    @starter = Stack.find_by!(source_key: "starter")
  end

  test "five repeatable lineups retain membership order roles and ongoing fees" do
    stacks = Stack.where.not(source_key: nil).order(:id)
    assert_equal [2, 3, 3, 3, 3], stacks.map { |stack| stack.cards.size }
    assert_equal [0, 0, 95, 95, 395], stacks.map(&:annual_fee)
    ids = stacks.pluck(:id)
    memberships = StackCard.order(:id).pluck(:id, :card_id)
    Stack.import_demo!
    assert_equal ids, stacks.pluck(:id)
    assert_equal memberships, StackCard.order(:id).pluck(:id, :card_id)
    assert_equal %w[us-capital-one-savor-student us-discover-it-student], @starter.cards.map(&:source_key)
    stacks.each do |stack|
      assert stack.stack_cards.all? { |member| member.role.present? }
      assert stack.cards.all? { |card| card.catalogue_status == "published" }
    end
  end

  test "missing published member rolls back import and hides stack without removing history" do
    member = @starter.cards.first
    member.update!(catalogue_status: "retired")
    @starter.update!(description: "Preserve this description")
    assert_raises(ActiveRecord::RecordNotFound) { Stack.import_demo! }
    assert_equal "Preserve this description", @starter.reload.description
    assert_not Stack.available.exists?(@starter.id)
    get stack_path(@starter)
    assert_response :success
    assert_select "form[action=?]", save_browse_wallet_items_path, count: 0
  end

  test "browse and home expose real artwork and detail includes roles and conditions" do
    payload = BrowseCatalogue.new.payload
    entry = payload[:stacks].find { |stack| stack[:id] == @starter.id.to_s }
    assert_equal @starter.cards.map { |card| card.id.to_s }, entry[:ids]
    assert_equal 2, entry[:roles].size
    assert_equal stack_path(@starter), entry[:url]
    get root_path
    assert_select '.fan-card.has-card-image img', minimum: 2
    get cards_path(tab: "stacks")
    assert_response :success
    get stack_path(@starter)
    assert_select '.stack-cards li', count: 2
    assert_select '.stack-role', text: /quarterly specialist/
    assert_select '.detail-art.has-card-image img', count: 2
    assert_select 'h2', 'How to use this stack'
    assert_select '.detail-figure', /\$0/
  end

  test "signed out save returns to the chosen stack after sign in" do
    post save_browse_wallet_items_path, params: { stack_id: @starter.id }
    assert_redirected_to new_user_session_path
    assert_equal stack_path(@starter), session['user_return_to']
  end

  test "saving a curated stack uses server membership preserves owned cards and is idempotent" do
    user = User.create!(email: "stacks@example.com", password: "password123", first_name: "Stacks")
    owned = user.wallet_items.create!(card: @starter.cards.first, status: "owned")
    sign_in user
    assert_difference 'user.wallet_items.count', 1 do
      post save_browse_wallet_items_path, params: { stack_id: @starter.id, card_ids: [Card.available.last.id] }
    end
    assert_redirected_to wallet_items_path
    assert_equal 'owned', owned.reload.status
    assert_equal 'planned', user.wallet_items.find_by!(card: @starter.cards.last).status
    assert_no_difference 'WalletItem.count' do
      post save_browse_wallet_items_path, params: { stack_id: @starter.id }, as: :json
    end
    assert_response :success
    assert_equal wallet_items_path, response.parsed_body['wallet_url']
    @starter.cards.last.update!(catalogue_status: 'retired')
    post save_browse_wallet_items_path, params: { stack_id: @starter.id }, as: :json
    assert_response :not_found
  end
end
