class ChatController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    cards = JSON.parse(Rails.root.join("data/cards.json").read)
    user_message = params[:message].to_s.strip
    history = params[:history] || []

    return render(json: { error: "Message required" }, status: 422) if user_message.blank?

    system_prompt = build_system_prompt(cards)
    messages = history.map { |m| { role: m["role"], content: m["content"] } }
    messages << { role: "user", content: user_message }

    # Choose provider based on config
    provider = Rails.application.config.respond_to?(:llm_provider) ? Rails.application.config.llm_provider : "stub"

    reply = case provider
            when "openai"   then call_openai(system_prompt, messages)
            when "anthropic" then call_anthropic(system_prompt, messages)
            else stub_response(user_message, cards)
            end

    render json: { reply: reply }
  end

  private

  def build_system_prompt(cards)
    <<~PROMPT
      You are Shuffl's credit card advisor — a friendly, knowledgeable expert who helps people find the right credit cards.

      You have PERFECT knowledge of every card in our database. Here is the complete card database:

      #{JSON.pretty_generate(cards)}

      RULES:
      - Only recommend cards that exist in the database above. NEVER invent cards or make up details.
      - When comparing cards, cite exact reward rates, fees, and perks from the data.
      - Be concise and conversational — this is a chat widget, not an essay.
      - If someone asks about a card or feature not in your database, say so honestly.
      - You can help with: comparing cards, explaining perks, suggesting cards for specific goals, explaining reward categories, and general credit card education.
      - Keep responses to 2-3 short paragraphs max unless the user asks for detail.
      - Use the card's exact name and issuer from the database.
    PROMPT
  end

  def stub_response(message, cards)
    msg = message.downcase
    if msg.include?("best") && msg.include?("travel")
      travel = cards.select { |c| c["categories"].include?("travel") }.sort_by { |c| -c["rewards"].fetch("travel", 0) }.first(3)
      "Great question! Our top travel cards are #{travel.map { |c| "**#{c['name']}** (#{c['rewards']['travel']}× on travel, $#{c['annualFee']}/yr)" }.join(', ')}. Want me to compare any of these in detail?"
    elsif msg.include?("best") && (msg.include?("cashback") || msg.include?("cash back"))
      cashback = cards.select { |c| c["categories"].include?("cashback") }.sort_by { |c| -c["rewards"].fetch("other", 0) }.first(3)
      "For cashback, check out #{cashback.map { |c| "**#{c['name']}** (#{c['rewards'].values.max}× top rate, $#{c['annualFee']}/yr)" }.join(', ')}. Any of these catch your eye?"
    elsif msg.include?("no") && msg.include?("fee")
      no_fee = cards.select { |c| c["annualFee"] == 0 }.first(3)
      "Here are some solid no-annual-fee options: #{no_fee.map { |c| "**#{c['name']}** by #{c['issuer']}" }.join(', ')}. Would you like to know more about any of them?"
    elsif msg.include?("student")
      student = cards.select { |c| c["categories"].include?("student") }.first(3)
      "We have some great student cards! Check out #{student.map { |c| "**#{c['name']}** by #{c['issuer']} ($#{c['annualFee']}/yr)" }.join(', ')}. These are designed for people building credit for the first time."
    elsif msg.include?("compare")
      "I'd love to help you compare cards! Tell me which two cards you're deciding between, or describe what you're looking for and I'll suggest the best options."
    else
      "I'm Shuffl's card advisor — I know every card in our database inside and out! You can ask me things like:\n\n• \"What's the best card for dining rewards?\"\n• \"Compare travel cards under $100/year\"\n• \"Which student cards have no annual fee?\"\n• \"What card has the best sign-up bonus?\"\n\nWhat would you like to know?"
    end
  end

  def call_openai(system_prompt, messages)
    api_key = Rails.application.credentials.dig(:openai, :api_key)
    return "OpenAI API key not configured. Add it to Rails credentials." unless api_key

    uri = URI("https://api.openai.com/v1/chat/completions")
    body = {
      model: "gpt-4o-mini",
      messages: [{ role: "system", content: system_prompt }] + messages,
      max_tokens: 500,
      temperature: 0.7
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key}")
    req.body = body.to_json

    res = http.request(req)
    parsed = JSON.parse(res.body)
    parsed.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."
  rescue => e
    "Error calling OpenAI: #{e.message}"
  end

  def call_anthropic(system_prompt, messages)
    api_key = Rails.application.credentials.dig(:anthropic, :api_key)
    return "Anthropic API key not configured. Add it to Rails credentials." unless api_key

    uri = URI("https://api.anthropic.com/v1/messages")
    body = {
      model: "claude-3-5-haiku-latest",
      max_tokens: 500,
      system: system_prompt,
      messages: messages
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "x-api-key" => api_key, "anthropic-version" => "2023-06-01")
    req.body = body.to_json

    res = http.request(req)
    parsed = JSON.parse(res.body)
    parsed.dig("content", 0, "text") || "Sorry, I couldn't generate a response."
  rescue => e
    "Error calling Anthropic: #{e.message}"
  end
end
