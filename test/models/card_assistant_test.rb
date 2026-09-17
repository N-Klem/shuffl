ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class CardAssistantTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls
    def initialize(*replies)
      @replies, @calls = replies, []
    end
    def call(**args)
      @calls << args
      # The one correction retry repeats the model's previous reply, so the
      # fail-closed tests stay as strict as before.
      value = @replies.shift || (@last if args[:input].to_s.include?('"correction"')) or raise "Unexpected API call"
      @last = value
      return value if value.key?("output")
      { "output" => [ { "type" => "message", "content" => [ { "type" => "output_text", "text" => value.to_json } ] } ] }
    end
  end

  setup do
    @user = User.create!(email: "assistant-model@example.com", password: "password123", first_name: "Chat")
    @card = Card.create!(name: "Dining test", issuer: "Example", card_type: "credit", source_key: "assistant-test",
      country: "US", currency: "USD", catalogue_status: "published", annual_fee: 0,
      catalogue_terms: { "fees" => { "foreign_purchase_percent" => "0" }, "rewards" => [
        { "category" => "Dining", "unit" => "cashback_percent", "rate" => "3", "conditions" => "Eligible restaurants only" }
      ] })
    @screen = { "allowed" => true, "online" => false, "recommendation" => true, "no_foreign_fees" => true,
      "dining_rate" => 3, "dining_unit" => "cashback_percent" }
    @answer = { "paragraphs" => [ { "text" => "Our catalogue records 3% cashback on eligible dining.", "kind" => "answer", "evidence_ids" => [ "card:#{@card.id}" ] } ],
      "card_ids" => [ @card.id ], "stack_ids" => [] }
  end

  def reply(client)
    CardAssistant.new(user: @user, client: client).reply("Find 3% dining cashback with no foreign fees")
  end

  test "real database cards supply facts and actions without wallet mutation" do
    client = FakeClient.new(@screen, @answer)
    assert_no_difference "WalletItem.count" do
      result = reply(client)
      assert_equal @card.name, result[:cards].first[:name]
      assert_equal "/cards/#{@card.id}", result[:sources].first[:url]
      assert_equal "Eligible restaurants only", result[:cards].first[:terms]["rewards"].first["conditions"]
    end
    context = JSON.parse(client.calls.last[:input])
    assert_includes context["eligible_recommendation_ids"], @card.id
    refute_includes client.calls.last[:input], @user.email
  end

  test "progress reports each stage as it starts, with the matching count" do
    notes = []
    CardAssistant.new(user: @user, client: FakeClient.new(@screen, @answer), progress: ->(text) { notes << text })
      .reply("Find 3% dining cashback with no foreign fees")
    assert_equal [ "Reading your question", "1 card matches", "Writing" ], notes
  end

  test "off-topic refusal stops before catalogue answer and web search" do
    client = FakeClient.new(@screen.merge("allowed" => false))
    assert_equal CardAssistant::REFUSAL, reply(client)[:paragraphs].first[:text]
    assert_equal 1, client.calls.size
  end

  test "ambiguous 3x cashback asks for units without generating a recommendation" do
    client = FakeClient.new(@screen.merge("dining_unit" => "unspecified"))
    result = reply(client)
    assert_match(/3% cashback/, result[:paragraphs].first[:text])
    assert_empty result[:cards]
    assert_equal 1, client.calls.size
  end

  test "unknown foreign fee cannot be treated as zero even if model recommends it" do
    @card.update!(catalogue_terms: @card.catalogue_terms.deep_merge("fees" => { "foreign_purchase_percent" => nil }))
    client = FakeClient.new(@screen, @answer)
    assert_equal CardAssistant::UNKNOWN, reply(client)[:paragraphs].first[:text]
    refute_includes JSON.parse(client.calls.last[:input])["eligible_recommendation_ids"], @card.id
  end

  test "points and temporary rates do not satisfy ongoing cashback" do
    %w[points_per_USD miles_per_USD].each do |unit|
      terms = @card.catalogue_terms.deep_dup
      terms["rewards"].first["unit"] = unit
      @card.update!(catalogue_terms: terms)
      assert_empty reply(FakeClient.new(@screen, @answer))[:cards]
    end
    terms = @card.catalogue_terms.deep_dup
    terms["rewards"].first.merge!("unit" => "cashback_percent", "temporary" => true)
    @card.update!(catalogue_terms: terms)
    assert_empty reply(FakeClient.new(@screen, @answer))[:cards]
  end

  test "invented card ids and invented or missing evidence fail closed" do
    invented = @answer.deep_dup
    invented["card_ids"] = [ 999999 ]
    assert_equal CardAssistant::UNKNOWN, reply(FakeClient.new(@screen, invented))[:paragraphs].first[:text]
    [ [], [ "web:made-up" ] ].each do |refs|
      invented = @answer.deep_dup
      invented["paragraphs"].first["evidence_ids"] = refs
      assert_equal CardAssistant::UNKNOWN, reply(FakeClient.new(@screen, invented))[:paragraphs].first[:text]
    end
  end

  test "retired cards cannot be recommended" do
    @card.update!(catalogue_status: "retired")
    assert_empty reply(FakeClient.new(@screen, @answer))[:cards]
  end

  test "stack payload uses actual server membership and details" do
    stack = Stack.create!(name: "Dining stack", category: "Dining", description: "One test card")
    stack.stack_cards.create!(card: @card, position: 0, role: "Dining")
    answer = { "paragraphs" => [ { "text" => "Our catalogue has a Dining stack.", "kind" => "answer", "evidence_ids" => [ "stack:#{stack.id}" ] } ], "card_ids" => [], "stack_ids" => [ stack.id ] }
    result = reply(FakeClient.new(@screen, answer))
    assert_equal [ @card.id ], result[:stacks].first[:cards].map { |card| card[:id] }
  end

  test "official URLs reject lookalike hosts credentials unsafe schemes and ports" do
    assert CardAssistant.issuer_url?("https://creditcards.chase.com/terms")
    %w[http://chase.com https://chase.com.evil.example https://evilchase.com https://user@chase.com https://chase.com:8443 javascript:alert(1)].each do |url|
      refute CardAssistant.issuer_url?(url), url
    end
  end

  test "web facts require genuine provider annotations on allowed issuer domains" do
    text = "Dining earns 3% cashback. [source]"
    web = { "output" => [ { "type" => "message", "content" => [ { "type" => "output_text", "text" => text,
      "annotations" => [ { "type" => "url_citation", "url" => "https://chase.com/terms", "title" => "Issuer terms", "start_index" => 25, "end_index" => 33 } ] } ] } ] }
    # The citation must be inside actual output boundaries.
    web["output"][0]["content"][0]["annotations"][0]["end_index"] = text.length
    answer = { "paragraphs" => [ { "text" => "Issuer terms show 3% cashback on dining.", "kind" => "answer", "evidence_ids" => [ "web:0" ] } ], "card_ids" => [], "stack_ids" => [] }
    client = FakeClient.new(@screen.merge("online" => true), web, answer)
    result = reply(client)
    assert_equal "https://chase.com/terms", result[:sources].first[:url]
    assert client.calls[1][:web]
    web["output"][0]["content"][0]["annotations"][0]["url"] = "https://chase.com.evil.example/terms"
    assert_equal CardAssistant::UNKNOWN, reply(FakeClient.new(@screen.merge("online" => true), web, answer))[:paragraphs].first[:text]
  end

  test "a missing catalogue answer triggers at most one issuer search" do
    unknown = { "paragraphs" => [ { "text" => "I cannot verify this.", "kind" => "unknown", "evidence_ids" => [] } ], "card_ids" => [], "stack_ids" => [] }
    web = { "output" => [] }
    client = FakeClient.new(@screen, unknown, web, unknown)
    result = reply(client)
    assert_empty result[:cards]
    assert_equal 1, client.calls.count { |call| call[:web] }
    assert_equal 4, client.calls.size
  end

  test "the complete current catalogue fits the bounded answer input" do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    Stack.import_demo!
    client = FakeClient.new(@screen.merge("recommendation" => false), @answer)
    reply(client)
    input = client.calls.last[:input]
    assert_operator input.bytesize, :<, 160_000
    entries = JSON.parse(input)["evidence"].select { |item| item["id"].start_with?("card:") }
    assert_equal Card.available.count, entries.size
    assert entries.all? { |item| item["facts"].key?("catalogue_terms") }
  end
end
