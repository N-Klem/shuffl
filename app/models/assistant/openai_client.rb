require "net/http"
require "json"
require "timeout"

module Assistant
  class OpenaiClient
    class Unavailable < StandardError; end
    attr_reader :input_tokens, :output_tokens

    def initialize
      @input_tokens = 0
      @output_tokens = 0
    end

    def self.configured?
      ENV["OPENAI_API_KEY"].present? && ENV.fetch("ASSISTANT_ENABLED", "true") == "true"
    end

    def call(instructions:, input:, max_output_tokens:, schema: nil, web: false)
      raise Unavailable unless self.class.configured?
      # Byte ceilings also bound worst-case token input, including future catalogue growth.
      raise Unavailable if input.bytesize > 160_000
      payload = {
        model: ENV.fetch("OPENAI_ASSISTANT_MODEL", "gpt-4.1-mini"),
        store: false, instructions: instructions, input: input,
        max_output_tokens: max_output_tokens
      }
      payload[:text] = { format: { type: "json_schema", name: "assistant_reply", strict: true, schema: schema } } if schema
      if web
        payload[:tools] = [ { type: "web_search", search_context_size: "low", filters: { allowed_domains: CardAssistant::ISSUER_DOMAINS } } ]
        payload[:tool_choice] = "required"
        payload[:max_tool_calls] = 1
        payload[:include] = [ "web_search_call.action.sources" ]
      end
      uri = URI("https://api.openai.com/v1/responses")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{ENV.fetch('OPENAI_API_KEY')}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 18, write_timeout: 5, max_retries: 0) do |http|
        http.request(request)
      end
      raise Unavailable unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      @input_tokens += data.dig("usage", "input_tokens").to_i
      @output_tokens += data.dig("usage", "output_tokens").to_i
      raise Unavailable unless data["status"] == "completed"
      data
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
      # Do not log prompts, credentials, provider bodies or personal information.
      raise Unavailable, e.class.name
    end

    def self.text(response)
      Array(response["output"]).select { |item| item["type"] == "message" }
        .flat_map { |item| Array(item["content"]) }
        .select { |item| item["type"] == "output_text" }.map { |item| item["text"] }.join("\n")
    end
  end
end
