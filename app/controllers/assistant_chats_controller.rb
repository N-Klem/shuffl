class AssistantChatsController < ApplicationController
  include ActionController::Live
  before_action :require_account

  def show
    render json: { messages: conversation.where(status: "completed").order(:id).last(8).map { |message|
      { question: message.question, reply: message.reply }
    }, remaining: AssistantMessage.remaining_for(current_user), configured: Assistant::OpenaiClient.configured? }
  end

  # The reply streams as newline-delimited JSON: a {"progress": "…"} line as each
  # stage of the work starts, then one final line holding the reply or an error.
  # Anything that fails before the first line uses an ordinary HTTP status.
  def create
    question = params[:message]
    unless question.is_a?(String) && question.strip.length.between?(1, 1500)
      return render json: { error: "Please enter a question of 1–1,500 characters." }, status: :unprocessable_entity
    end
    unless Assistant::OpenaiClient.configured?
      return render json: { error: "Chat isn't connected yet. You can still browse cards and stacks." }, status: :service_unavailable
    end
    # Never accept client-supplied history, roles, model names, instructions or IDs.
    history = conversation.where(status: "completed").order(:id).last(3).map do |message|
      { question: message.question, answer: Array(message.reply["paragraphs"]).map { |p| p["text"] }.join("\n").first(3000) }
    end
    message = AssistantMessage.reserve!(user: current_user, conversation_key: conversation_key, question: question.strip)
    client = Assistant::OpenaiClient.new
    progress = ->(text) { write_line(progress: text) }
    # Finish below Heroku's router timeout; there are no unbounded agent loops or retries.
    reply = Timeout.timeout(24) do
      CardAssistant.new(user: current_user, history: history, client: client, progress: progress).reply(question.strip)
    end
    # A clear request in another tab must not resurrect erased conversation content.
    saved = AssistantMessage.where(id: message.id, status: "pending").update_all(status: "completed", reply: reply,
      input_tokens: client.input_tokens, output_tokens: client.output_tokens, updated_at: Time.current)
    return finish({ error: "This conversation was cleared. Please start a new message." }, status: :conflict) if saved.zero?
    finish({ reply: reply, remaining: AssistantMessage.remaining_for(current_user) })
  rescue AssistantMessage::LimitReached => e
    response.set_header("Retry-After", "60")
    finish({ error: e.message }, status: :too_many_requests)
  rescue Assistant::OpenaiClient::Unavailable, Timeout::Error, ActionController::Live::ClientDisconnected => e
    Rails.logger.warn("Assistant chat failed: #{e.class} #{e.message}")
    AssistantMessage.where(id: message.id, status: "pending").update_all(status: "failed",
      input_tokens: client&.input_tokens.to_i, output_tokens: client&.output_tokens.to_i) if message
    finish({ error: "I couldn't verify an answer right now. Please try again shortly." }, status: :service_unavailable)
  ensure
    response.stream.close if response.committed? && !response.stream.closed?
  end

  def destroy
    # Keep anonymous usage metadata for quotas, but erase conversation content.
    conversation.update_all(question: "[cleared]", reply: {}, status: "cleared", updated_at: Time.current)
    session[:assistant_conversation_key] = SecureRandom.uuid
    head :no_content
  end

  private

  def write_line(payload)
    response.headers["Content-Type"] = "application/x-ndjson" unless response.committed?
    response.stream.write("#{JSON.generate(payload)}\n")
  end

  # Once a progress line has gone out the status is already 200, so the outcome
  # travels in the final line instead; before that, it is a normal JSON response.
  def finish(payload, status: :ok)
    if response.committed?
      write_line(payload)
    else
      render json: payload, status: status
    end
  end

  def require_account
    render json: { error: "Sign in to chat.", sign_in_url: new_user_session_path }, status: :unauthorized unless user_signed_in?
  end

  def conversation_key
    session[:assistant_conversation_key] ||= SecureRandom.uuid
  end

  def conversation
    AssistantMessage.where(user: current_user, conversation_key: conversation_key)
  end
end
