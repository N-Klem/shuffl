ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class HomePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @card = Card.create!(name: "Home Feature Card", issuer: "Test", network: "Visa", card_type: "Credit",
                         annual_fee: 0, reward_rate: 3, best_for: "Dining", perks: "Standout home perk")
    @stack = Stack.create!(name: "Home Feature Stack", category: "Dining", description: "For testing the home page.")
    @stack.stack_cards.create!(card: @card)
    2.times do |index|
      card = Card.create!(name: "Home companion #{index}", issuer: "Test", network: "Visa", card_type: "Credit",
                          annual_fee: 0, reward_rate: 1, best_for: "Cashback")
      @stack.stack_cards.create!(card: card, position: index + 1)
    end
  end

  test "home page features real stacks and their real cards, not hardcoded names" do
    get root_path
    assert_response :success
    # The featured tiles are driven by real Stack records...
    assert_select ".stack-tile [aria-label=?]", "Reveal #{@stack.name} cards"
    # ...showing that stack's actual cards and a benefit line drawn from the card.
    assert_select ".stack-tile .fan-card .name", text: @card.name
    assert_select ".stack-tile .fan-card .benefit", text: "Standout home perk"
  end

  test "home page has the meta description and social card tags" do
    get root_path
    assert_select "meta[name='description']"
    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:image']"
  end

  test "signed-out visitors see no continuity strip" do
    get root_path
    assert_select ".home-continue", count: 0
  end

  test "a signed-in visitor with no history sees no continuity strip" do
    sign_in User.create!(first_name: "Newbie", email: "newbie@example.com", password: "password123")
    get root_path
    assert_select ".home-continue", count: 0
    assert_select ".mobile-navigation a[href=?]", new_quiz_response_path
  end

  test "a signed-in visitor with saved cards can access the wallet through navigation" do
    user = User.create!(first_name: "Saver", email: "saver@example.com", password: "password123")
    user.wallet_items.create!(card: @card)
    sign_in user
    get root_path
    assert_select ".home-continue", count: 0
    assert_select ".mobile-navigation a[href=?]", wallet_items_path
  end
end
