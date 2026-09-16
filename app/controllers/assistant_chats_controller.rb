class AssistantChatsController < ApplicationController
  before_action :require_account

  def show
    render json: { messages: conversation.where(status: "completed").order(:id).last(8).map { |message|
      { question: message.question, reply: message.reply }
    }, remaining: AssistantMessage.remaining_for(current_user), configured: Assistant::OpenaiClient.configured? }
  end

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
    # Finish below Heroku's router timeout; there are no unbounded agent loops or retries.
    reply = Timeout.timeout(24) { CardAssistant.new(user: current_user, history: history, client: client).reply(question.strip) }
    # A clear request in another tab must not resurrect erased conversation content.
    saved = AssistantMessage.where(id: message.id, status: "pending").update_all(status: "completed", reply: reply,
      input_tokens: client.input_tokens, output_tokens: client.output_tokens, updated_at: Time.current)
    return render json: { error: "This conversation was cleared. Please start a new message." }, status: :conflict if saved.zero?
    render json: { reply: reply, remaining: AssistantMessage.remaining_for(current_user) }
  rescue AssistantMessage::LimitReached => e
    response.set_header("Retry-After", "60")
    render json: { error: e.message }, status: :too_many_requests
  rescue Assistant::OpenaiClient::Unavailable, Timeout::Error
    AssistantMessage.where(id: message.id, status: "pending").update_all(status: "failed",
      input_tokens: client&.input_tokens.to_i, output_tokens: client&.output_tokens.to_i) if message
    render json: { error: "I couldn't verify an answer right now. Please try again shortly." }, status: :service_unavailable
  end

  def destroy
    # Keep anonymous usage metadata for quotas, but erase conversation content.
    conversation.update_all(question: "[cleared]", reply: {}, status: "cleared", updated_at: Time.current)
    session[:assistant_conversation_key] = SecureRandom.uuid
    head :no_content
  end

  private

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
