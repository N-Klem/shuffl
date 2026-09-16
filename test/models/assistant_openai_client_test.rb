ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class AssistantOpenaiClientTest < ActiveSupport::TestCase
  setup do
    @old_key, @old_enabled = ENV["OPENAI_API_KEY"], ENV["ASSISTANT_ENABLED"]
    ENV["OPENAI_API_KEY"], ENV["ASSISTANT_ENABLED"] = "test-placeholder-not-a-real-key", "true"
  end

  teardown do
    ENV["OPENAI_API_KEY"], ENV["ASSISTANT_ENABLED"] = @old_key, @old_enabled
  end

  def with_http(body:, code: "200")
    original = Net::HTTP.method(:start)
    response = (code == "200" ? Net::HTTPOK : Net::HTTPTooManyRequests).new("1.1", code, "Test")
    response.define_singleton_method(:body) { body }
    captured = {}
    http = Object.new
    http.define_singleton_method(:request) do |request|
      captured[:request] = request
      response
    end
    Net::HTTP.define_singleton_method(:start) do |*args, **options, &block|
      captured[:args], captured[:options] = args, options
      block.call(http)
    end
    yield captured
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  test "request keeps credentials server-side disables storage and bounds search" do
    data = { status: "completed", output: [], usage: { input_tokens: 10, output_tokens: 2 } }
    with_http(body: data.to_json) do |captured|
      client = Assistant::OpenaiClient.new
      client.call(instructions: "Only cards", input: "Card question", max_output_tokens: 100, web: true)
      body = JSON.parse(captured[:request].body)
      assert_equal false, body["store"]
      assert_equal 1, body["max_tool_calls"]
      assert_equal "required", body["tool_choice"]
      assert_equal CardAssistant::ISSUER_DOMAINS, body["tools"].first.dig("filters", "allowed_domains")
      assert_equal 0, captured[:options][:max_retries]
      assert_equal [ "api.openai.com", 443 ], captured[:args]
      assert_equal 10, client.input_tokens
      assert_equal 2, client.output_tokens
      refute_includes captured[:request].body, ENV["OPENAI_API_KEY"]
    end
  end

  test "truncated and error responses do not become answers" do
    [ { status: "incomplete", output: [] }.to_json, "not json" ].each do |body|
      with_http(body: body) do
        assert_raises(Assistant::OpenaiClient::Unavailable) do
          Assistant::OpenaiClient.new.call(instructions: "Only cards", input: "hello", max_output_tokens: 100)
        end
      end
    end
    with_http(body: "private provider error", code: "429") do
      error = assert_raises(Assistant::OpenaiClient::Unavailable) do
        Assistant::OpenaiClient.new.call(instructions: "Only cards", input: "hello", max_output_tokens: 100)
      end
      refute_includes error.message, "private provider error"
    end
  end

  test "oversized inputs and kill switch stop calls" do
    assert_raises(Assistant::OpenaiClient::Unavailable) do
      Assistant::OpenaiClient.new.call(instructions: "Only cards", input: "x" * 160_001, max_output_tokens: 100)
    end
    ENV["ASSISTANT_ENABLED"] = "false"
    assert_raises(Assistant::OpenaiClient::Unavailable) do
      Assistant::OpenaiClient.new.call(instructions: "Only cards", input: "hello", max_output_tokens: 100)
    end
  end
end
