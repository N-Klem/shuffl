class QuizResponsesController < ApplicationController
  before_action :authenticate_user!

  QUESTIONS = Card::QUIZ_QUESTIONS

  def new
    session[:quiz_step] ||= 0
    session[:quiz_answers] ||= {}

    @question = QUESTIONS[session[:quiz_step]]
    @step = session[:quiz_step] + 1
    @total = QUESTIONS.size
  end

  def create
    question = QUESTIONS[session[:quiz_step].to_i]
    session[:quiz_answers] ||= {}

    if question[:type] == :multi
      session[:quiz_answers][question[:key]] = Array(params[:answer]).reject(&:blank?).first(question[:max_select])
    else
      session[:quiz_answers][question[:key]] = params[:answer]
    end

    session[:quiz_step] = session[:quiz_step].to_i + 1

    if session[:quiz_step] < QUESTIONS.size
      redirect_to new_quiz_response_path
    else
      top_cards = Card.ranked_for(session[:quiz_answers]).first(5)

      @quiz_response = current_user.quiz_responses.create!(
        answers: session[:quiz_answers].to_json,
        top_card_ids: top_cards.map(&:id).to_json,
        completed_at: Time.current
      )

      session[:quiz_step] = 0
      session[:quiz_answers] = {}

      redirect_to @quiz_response
    end
  end

  def show
    @quiz_response = current_user.quiz_responses.find(params[:id])
    ids = JSON.parse(@quiz_response.top_card_ids)
    @cards = ids.map { |id| Card.find(id) }
  end
end
