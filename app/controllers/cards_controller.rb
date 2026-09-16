class CardsController < ApplicationController
  def index
    @browse_payload = BrowseCatalogue.new.payload
  end

  def show
    @card = Card.find(params[:id])
    @card_total = Card.available.count
    @stacks = @card.stacks.available.order(:name)
    @similar_cards = similar_cards
    rank_for_visitor if latest_quiz_response
  end

  private

  # Cards that share at least one "best for" category with this one.
  def similar_cards
    categories = @card.best_for.to_s.split(",").map(&:strip)
    return [] if categories.empty?

    Card.available.where.not(id: @card.id).order(:name).select do |card|
      (card.best_for.to_s.split(",").map(&:strip) & categories).any?
    end.first(3)
  end

  # Where this card lands when every card is scored against the visitor's answers.
  def rank_for_visitor
    answers = JSON.parse(latest_quiz_response.answers.presence || "{}")
    ranked = Card.ranked_for(answers)
    @quiz_rank = ranked.index(@card)&.+(1)
    @quiz_total = ranked.size
    top_ids = JSON.parse(latest_quiz_response.top_card_ids.presence || "[]")
    @in_recommended_stack = top_ids.include?(@card.id)
  rescue JSON::ParserError
    @quiz_rank = nil
  end
end
