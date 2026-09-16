class QuizResponsesController < ApplicationController
  def new
    session[:quiz_answers] ||= {}
    resume_draft if session[:quiz_answers].empty?

    questions = current_questions
    furthest = resolve_step(questions)
    requested = params[:step].present? ? params[:step].to_i : session[:quiz_step].to_i
    session[:quiz_step] = requested.clamp(0, furthest)

    prepare_question(questions)
  end

  def create
    session[:quiz_answers] ||= {}
    questions = current_questions
    session[:quiz_step] = session[:quiz_step].to_i.clamp(0, resolve_step(questions))

    unless params[:step].to_s == session[:quiz_step].to_s &&
           params[:quiz_token].present? && params[:quiz_token] == session[:quiz_token]
      return redirect_to new_quiz_response_path, status: :see_other
    end

    question = questions[session[:quiz_step]]
    values = submitted_values(question)

    unless Card.valid_quiz_answer?(question, values)
      prepare_question(questions)
      @error =
        case question[:type]
        when :budget then "Enter a maximum annual budget in USD, zero or above, with up to two decimal places."
        when :ranked then "Pick up to #{question[:max_select]}, in the order that matters most."
        when :multi then "Choose up to #{question[:max_select]} answers, or No preference on its own."
        else "Choose one answer to continue."
        end
      return render :new, status: :unprocessable_entity
    end

    session[:quiz_answers][question[:key]] =
      [ :multi, :ranked ].include?(question[:type]) ? values : values.first

    # Only discard answers that no longer belong to the newly chosen path.
    # Merely visiting an earlier question never destroys answers.
    questions = current_questions
    keys = questions.map { |q| q[:key] }
    session[:quiz_answers].keep_if { |key, value| keys.include?(key) && Card.valid_quiz_answer?(questions.find { |q| q[:key] == key }, value) }
    session.delete(:quiz_token)
    next_step = session[:quiz_step] + 1

    if next_step < questions.size
      session[:quiz_step] = next_step
      redirect_to new_quiz_response_path, status: :see_other
    else
      finish_quiz
    end
  end

  def save_progress
    session[:quiz_answers] ||= {}

    if session[:quiz_answers].empty?
      return redirect_to new_quiz_response_path, alert: "Answer a question first and we'll save your place."
    end

    draft = resumable_draft || QuizResponse.new(user: current_user)
    draft.update!(user: current_user, answers: session[:quiz_answers].to_json)
    session[:draft_quiz_response_id] = draft.id unless current_user

    if current_user
      session[:quiz_step] = 0
      session[:quiz_answers] = {}
      redirect_to root_path, notice: "Saved. Pick up where you left off whenever you're ready."
    else
      redirect_to new_user_session_path,
                  notice: "Sign in and we'll keep your answers so far — you can finish the quiz later."
    end
  end

  def show
    @quiz_response = QuizResponse.find(params[:id])
    @show_quiz_finish = session[:quiz_finish_id].to_s == @quiz_response.id.to_s
    session.delete(:quiz_finish_id) if @show_quiz_finish
    ids = JSON.parse(@quiz_response.top_card_ids)
    @cards = ids.filter_map { |id| Card.find_by(id: id) }
    @results_payload = ResultsStack.new(@quiz_response).payload
  end

  private

  # The full ten-question path, tailored to the highest-ranked goal.
  def current_questions
    Card.quiz_questions_for(session[:quiz_answers] || {})
  end

  # Land on the first unanswered question, or the last question if all are
  # answered (the next submit will finish the quiz).
  def resolve_step(questions)
    unanswered = questions.index { |q| !Card.valid_quiz_answer?(q, session[:quiz_answers][q[:key]]) }
    unanswered || [ questions.size - 1, 0 ].max
  end

  def resumable_draft
    @resumable_draft ||=
      if current_user
        current_user.quiz_responses.drafts.order(:updated_at).last
      elsif session[:draft_quiz_response_id].present?
        QuizResponse.drafts.where(id: session[:draft_quiz_response_id], user_id: nil).first
      end
  end

  # Restore saved answers from a draft and land on the first unanswered question.
  def resume_draft
    draft = resumable_draft
    return if draft.blank?

    answers = draft.answers_hash
    return if answers.empty?

    session[:quiz_answers] = answers
    questions = current_questions
    session[:quiz_answers].keep_if do |key, value|
      question = questions.find { |q| q[:key] == key }
      question && Card.valid_quiz_answer?(question, value)
    end
    session[:quiz_step] = resolve_step(current_questions)
    flash.now[:notice] = "Welcome back — picking up where you left off."
  end

  def submitted_values(question)
    if question[:type] == :budget
      value = params[:answer] == "Custom" ? params[:custom_budget] : params[:answer]
      return [value.to_s.strip]
    end
    checked = Array(params[:answer]).reject(&:blank?).uniq
    return checked unless question[:type] == :ranked

    ordered = params[:ordered].to_s.split("").reject(&:blank?)
    ordered &= checked
    ordered.presence || checked
  end

  def prepare_question(questions)
    session[:quiz_token] = SecureRandom.hex(16)
    step = session[:quiz_step]
    @question = questions[step]
    @current_index = step
    @step = step + 1
    @total = questions.size
    @previous_step = step > 0 ? step - 1 : nil
    @selected = Array(session[:quiz_answers][@question[:key]])
  end

  def finish_quiz
    answers = session[:quiz_answers]
    top_cards = QuizRecommendation.new(answers).cards

    @quiz_response = resumable_draft || QuizResponse.new(user: current_user)
    @quiz_response.update!(
      user: current_user || @quiz_response.user,
      answers: session[:quiz_answers].to_json,
      top_card_ids: top_cards.map(&:id).to_json,
      completed_at: Time.current
    )
    session.delete(:draft_quiz_response_id)
    session[:quiz_step] = 0
    session[:quiz_answers] = {}
    session[:last_quiz_response_id] = @quiz_response.id
    session[:quiz_finish_id] = @quiz_response.id
    redirect_to @quiz_response, status: :see_other
  end
end
