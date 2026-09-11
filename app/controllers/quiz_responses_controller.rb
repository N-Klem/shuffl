class QuizResponsesController < ApplicationController
  QUESTIONS = Card::QUIZ_QUESTIONS

  def new
    session[:quiz_answers] ||= {}
    session[:quiz_step] = current_step
    if params[:step].present?
      requested = params[:step].to_i
      session[:quiz_step] = requested if requested.between?(0, current_step)
    end
    prepare_question
  end

  def create
    session[:quiz_answers] ||= {}
    session[:quiz_step] = current_step
    # Ignore repeated submissions and forms left open in another tab.
    unless params[:step].to_s == current_step.to_s
      return redirect_to new_quiz_response_path, status: :see_other
    end

    question = QUESTIONS[current_step]
    values = Array(params[:answer]).reject(&:blank?).uniq
    valid_count = question[:type] == :multi ? values.size.between?(1, question[:max_select]) : values.size == 1
    unless valid_count && (values - question[:options]).empty?
      prepare_question
      @error = question[:type] == :multi ? "Choose between 1 and #{question[:max_select]} answers." : "Choose one answer to continue."
      return render :new, status: :unprocessable_entity
    end

    session[:quiz_answers][question[:key]] = question[:type] == :multi ? values : values.first

    if current_step < QUESTIONS.size - 1
      session[:quiz_step] = current_step + 1
      redirect_to new_quiz_response_path, status: :see_other
    else
      top_cards = Card.ranked_for(session[:quiz_answers]).first(5)
      @quiz_response = QuizResponse.create!(
        user: current_user,
        answers: session[:quiz_answers].to_json,
        top_card_ids: top_cards.map(&:id).to_json,
        completed_at: Time.current
      )
      session[:quiz_step] = 0
      session[:quiz_answers] = {}
      redirect_to @quiz_response, status: :see_other
    end
  end

  def show
    @quiz_response = QuizResponse.find(params[:id])
    ids = JSON.parse(@quiz_response.top_card_ids)
    @cards = ids.filter_map { |id| Card.find_by(id: id) }
    @results_payload = ResultsStack.new(@quiz_response).payload
  end

  private

  def current_step
    session[:quiz_step].to_i.clamp(0, QUESTIONS.size - 1)
  end

  def prepare_question
    @question = QUESTIONS[current_step]
    @step = current_step + 1
    @total = QUESTIONS.size
    @selected = Array(session[:quiz_answers][@question[:key]])
  end
end
