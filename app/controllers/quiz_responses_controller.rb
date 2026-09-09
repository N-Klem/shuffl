class QuizResponsesController < ApplicationController
  before_action :authenticate_user!

  def new
    @questions = Card::QUIZ_QUESTIONS
  end

  def create
    answers = answers_params.to_h
    answers["other_priorities"] = Array(answers["other_priorities"]).reject(&:blank?).first(3)

    top_cards = Card.ranked_for(answers).first(5)

    @quiz_response = current_user.quiz_responses.create!(
      answers: answers.to_json,
      top_card_ids: top_cards.map(&:id).to_json,
      completed_at: Time.current
    )

    redirect_to @quiz_response
  end

  def show
    @quiz_response = current_user.quiz_responses.find(params[:id])
    ids = JSON.parse(@quiz_response.top_card_ids)
    @cards = ids.map { |id| Card.find(id) }
  end

  private

  def answers_params
    params.fetch(:answers, {}).permit(
      :top_priority, :dining_frequency, :travel_frequency, :annual_fee_tolerance,
      :international_travel, :credit_score, :rewards_type, :welcome_bonus_importance,
      :student, :drives_regularly, :streaming_spend,
      other_priorities: []
    )
  end
end
