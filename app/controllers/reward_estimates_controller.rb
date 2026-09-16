class RewardEstimatesController < ApplicationController
  # Stateless calculation of public catalogue data; never writes quiz or wallet records.
  def create
    ids = params[:card_ids]
    amounts = params[:amounts]
    unless ids.is_a?(Array) && ids.size.between?(1, 30) && ids.all? { |id| id.to_s.match?(/\A\d+\z/) } && RewardsCalculator.valid_amounts?(amounts)
      return render json: { error: "Choose cards and enter six valid monthly amounts." }, status: :unprocessable_entity
    end
    records = Card.where(id: ids).index_by(&:id)
    cards = ids.map { |id| records[id.to_i] }.uniq
    return render json: { error: "A selected card is no longer available." }, status: :unprocessable_entity if cards.include?(nil)

    if params[:plan] == true
      choices = params[:programmes] || Array.new(6, "")
      unless SpendingPlan.valid_choices?(choices)
        return render json: { error: "Choose rewards for each spending category." }, status: :unprocessable_entity
      end
      render json: SpendingPlan.new(cards: cards, amounts: amounts, confirmed: params[:confirmed], programmes: choices).call
    else
      render json: RewardsCalculator.new(cards: cards, amounts: amounts, confirmed: params[:confirmed]).call
    end
  end
end
