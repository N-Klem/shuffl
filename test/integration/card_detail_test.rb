ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class CardDetailTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @card = Card.create!(name: "Detail test", issuer: "Test", network: "Visa", card_type: "Credit",
                         annual_fee: 95, reward_rate: 4, best_for: "Travel, Dining",
                         perks: "Lounge access, Trip cover", credit_score_min: 690)
    @similar = Card.create!(name: "Similar test", issuer: "Test", network: "Visa", card_type: "Credit",
                            annual_fee: 0, reward_rate: 2, best_for: "Travel")
    @unrelated = Card.create!(name: "Unrelated test", issuer: "Test", network: "Visa", card_type: "Credit",
                              annual_fee: 0, reward_rate: 1, best_for: "Student")
    @stack = Stack.create!(name: "Test stack", category: "Travel", description: "For testing.")
    @stack.stack_cards.create!(card: @card)
  end

  test "supplied artwork renders and reaches the client catalogues" do
    @card.update_columns(source_key: "us-chase-sapphire-preferred")
    image = "/card-images/us-chase-sapphire-preferred.png"

    get card_path(@card)
    assert_response :success
    assert_select ".detail-art.has-card-image img[src=?]", image
    assert_equal image, @card.results_data[:imageUrl]
    assert_equal image, BrowseCatalogue.new.payload[:cards].find { |card| card[:id] == @card.id.to_s }[:imageUrl]
  end

  test "image manifest covers the complete catalogue and preserves the legacy fallback" do
    catalogue_keys = JSON.parse(Rails.root.join("data/real_cards/catalogue.json").read).fetch("cards").map { |card| card.fetch("source_key") }
    assert_equal catalogue_keys.sort, Card.image_paths.keys.sort
    Card.image_paths.each_value do |path|
      assert Rails.root.join("public", path.delete_prefix("/")).file?, "Missing image: #{path}"
    end
    assert_nil @card.image_path
  end

  test "card page renders facts, perks, related stacks and similar cards" do
    get card_path(@card)
    assert_response :success
    assert_select "h1", "Detail test"
    assert_select ".detail-figure", /4x/
    assert_select ".detail-facts .value", text: /\$95/
    assert_select ".detail-perks li", count: 2
    assert_select ".detail-tags li", count: 2
    assert_select ".detail-tags a[href=?]", cards_path(category: "Travel")
    assert_select ".detail-stacks a", text: /Test stack/
    assert_select ".mini-cards li", count: 1
    assert_select ".mini-cards .name", "Similar test"
    assert_select "meta[property='og:title'][content='Detail test · Shuffl']"
  end

  test "signed-out visitors are invited to sign in rather than shown a broken button" do
    get card_path(@card)
    assert_select "a.btn-wallet", "Sign in to save this card"
    assert_select "form[action='#{wallet_items_path}']", count: 0
  end

  test "card page invites visitors without a quiz result to take the quiz" do
    get card_path(@card)
    assert_select ".detail-foryou--empty a", "Take the quiz"
    assert_select ".detail-foryou-rank", count: 0
  end

  # Complete the ten-question journey using the rendered form metadata.
  def complete_quiz(choice = :first)
    get new_quiz_response_path
    loop do
      field = css_select("input[name='step']").first
      break if field.nil?
      index = field["value"].to_i
      key = css_select("input[name='question_key']").first["value"]
      question = Card::QUIZ_QUESTION_POOL[key]
      answer = question[:type] == :ranked ? question[:options].first(3)
             : choice == :last ? question[:options].last : question[:options].first
      answer = "300" if question[:type] == :budget
      post quiz_responses_path, params: { step: index, answer: answer, quiz_token: css_select("input[name='quiz_token']").first["value"] }
      follow_redirect!
    end
  end

  test "after the quiz the card page shows the card's rank, and signing in claims the result" do
    complete_quiz
    quiz_response = QuizResponse.order(:id).last
    assert_nil quiz_response.user_id

    get card_path(@card)
    assert_select ".detail-foryou-rank", /#\d+/
    assert_select ".detail-foryou a[href='#{quiz_response_path(quiz_response)}']"

    user = User.create!(first_name: "Quiz", email: "quiz-claim@example.com", password: "password123")
    sign_in user
    get root_path
    assert_equal user.id, quiz_response.reload.user_id
  end

  test "stack page lists its cards with links to each card" do
    get stack_path(@stack)
    assert_response :success
    assert_select "h1", "Test stack"
    assert_select ".stack-cards li", count: 1
    assert_select ".stack-cards a[href='#{card_path(@card)}']"
    assert_select ".detail-figure", /\$95/
  end

  test "navbar reflects sign-in state and shows flash messages" do
    get root_path
    assert_select ".nav-account a", text: "Sign in"
    assert_select '.account-toggle[aria-expanded="false"]'
    assert_select '.account-menu a', text: "Create account"
    assert_select '.nav-links a', text: "Browse"
    assert_select '.nav-links a', text: "Cards", count: 0
    assert_select '.nav-links a', text: "Stacks", count: 0
    assert_select ".wordmark", text: "shuffl"
    assert_select ".wordmark .wordmark-dot"

    user = User.create!(first_name: "Nav", email: "nav-test@example.com", password: "password123")
    sign_in user
    post wallet_items_path, params: { card_id: @card.id }
    follow_redirect!
    assert_select '.account-toggle[aria-label="Account menu for Nav"]'
    assert_select '.account-menu .dropdown-header', text: "Signed in as Nav"
    assert_select '.account-menu button', text: "Sign out"
    assert_select '.account-menu a', text: "Sign in", count: 0
    assert_select ".flash", text: /Card added to your wallet/
  end

  test "results page offers saving without the retired share control" do
    complete_quiz
    assert_select "button#save-stack", text: "Save this stack"
    assert_select "[data-controller='share'] button", count: 0
  end
end
