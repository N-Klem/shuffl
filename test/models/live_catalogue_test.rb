ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class LiveCatalogueTest < ActiveSupport::TestCase
  setup do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    @legacy = Card.create!(name: "Historical demo", issuer: "Demo", network: "Visa", card_type: "Credit", annual_fee: 0, reward_rate: 2)
    @user = User.create!(first_name: "History", email: "catalogue-history@example.com", password: "password123")
    @user.wallet_items.create!(card: @legacy)
    @quiz = QuizResponse.create!(answers: '{}', top_card_ids: [@legacy.id].to_json, completed_at: Time.current)
    @stack = Stack.create!(name: "Old stack", category: "Travel")
    @stack.cards << @legacy
  end

  test "staging imports 30 draft cards and preserves unknowns and complete research" do
    candidate = CardCandidate.find_by!(source_key: "us-chase-freedom-unlimited")
    facts = candidate.research.deep_dup
    facts["network"] = nil
    facts["fees"]["foreign_purchase_percent"] = nil
    candidate.update!(research: facts)
    assert_difference "Card.count", 30 do
      assert_equal 30, Card.import_us_candidates!
    end
    card = Card.find_by!(source_key: "us-chase-freedom-unlimited")
    assert_equal "draft", card.catalogue_status
    assert_nil card.network
    assert_nil card.foreign_transaction_fee
    assert_nil card.reward_rate
    assert_equal CardCandidate.find_by!(source_key: card.source_key).research, card.catalogue_terms
    assert_nil BrowseCatalogue.new.payload[:cards].find { |row| row[:id] == card.id.to_s }
  end

  test "publication and repeat import preserve identities and historical references" do
    Card.publish_us_demo!
    assert_equal 30, Card.available.count
    assert_equal "retired", @legacy.reload.catalogue_status
    refute Stack.available.exists?(@stack.id)
    assert_equal [@legacy.id], @user.cards.pluck(:id)
    data = ResultsStack.new(@quiz).payload
    assert_equal @legacy.id, data[:cards][data[:selected].first][:id]
    wallet = WalletDashboard.new(@user).payload
    assert_equal @legacy.id, wallet[:cards].first[:cardId]
    refute wallet[:catalogue].any? { |card| card[:id] == @legacy.id }
    candidate = CardCandidate.find_by!(source_key: "us-chase-sapphire-preferred")
    id = Card.find_by!(source_key: candidate.source_key).id
    candidate.update!(name: "Renamed product")
    assert_no_difference "Card.count" do
      Card.publish_us_demo!
    end
    assert_equal id, Card.find_by!(source_key: candidate.source_key).id
    assert_equal "Renamed product", Card.find(id).name
    assert Card.ranked_for({}).all? { |card| card.catalogue_status == "published" }
    refute Card.ranked_for("credit_score" => "Excellent (740+)", "employment_status" => "Employed full-time").any? { |card| Array(card.catalogue_terms["recommendation_conditions"]).include?("Student status") }
    refute Card.ranked_for("travel_programs" => ["No preference"]).any? { |card| Card::TRAVEL_PROGRAM_CARDS.key?(card.source_key) }
    assert Card.ranked_for("credit_score" => "Good (670–739)", "travel_programs" => ["Delta SkyMiles"]).any? { |card| card.source_key == "us-delta-gold" }
  end

  test "a malformed candidate rolls back imports" do
    candidate = CardCandidate.order(:shortlist_position).last
    candidate.update_column(:research, {})
    assert_no_difference "Card.count" do
      assert_raises(ActiveRecord::RecordInvalid) { Card.import_us_candidates! }
    end
  end

  test "published payload retains reward units and avoids invented numerical estimates" do
    Card.publish_us_demo!
    card = Card.find_by!(source_key: "us-chase-sapphire-preferred")
    row = BrowseCatalogue.new.payload[:cards].find { |data| data[:id] == card.id.to_s }
    assert_equal "points_per_USD", row[:rewardRules].first["unit"]
    assert_equal card.catalogue_terms["perks"], card.perk_list
    assert_equal card.perk_list, row[:perks]
    assert_includes row[:welcomeOffer], "5,000"
    assert_equal Array.new(6), card.results_data[:rates]
    assert_equal false, card.results_data[:estimatesAvailable]
  end
end
