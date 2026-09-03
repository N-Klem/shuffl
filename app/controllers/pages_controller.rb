class PagesController < ApplicationController
  before_action :load_data
  def home; end
  def questionnaire; end
  def wallet; end

  def results
    if params[:stack].present?
      @stack = @stacks.find { |s| s["id"] == params[:stack] } || @stacks.first
      @cards = @stack["cardIds"].filter_map { |id| @cards_by_id[id] }
    else
      answers = {
        credit_band:     params[:credit_band] || "unknown",
        life_stage:      params[:life_stage] || "professional",
        income:          params[:income] || "30k_50k",
        existing_cards:  params[:existing_cards] || "none",
        authorized_user: params[:authorized_user] || "no",
        goal:            params[:goal] || "maximize_rewards",
        preference:      params[:preference] || "cashback",
        top_category:    params[:top_category] || "dining",
        categories:      Array(params[:categories]).presence || %w[dining groceries other],
        monthly_spend:   params[:monthly_spend] || "1000_2000",
        foreign_spending: params[:foreign_spending] || "never",
        loyalty_program: params[:loyalty_program] || "no_preference",
        perks:           Array(params[:perks]),
        fee:             params[:fee] || "low",
        card_network:    params[:card_network] || "no_preference",
        signup_bonus:    params[:signup_bonus] || "nice",
        card_count:      params[:card_count] || "2_3"
      }

      @cards = RecommendationService.new(@all_cards, answers).call

      travel = answers[:preference] == "travel"
      card_count = @cards.length
      @stack = {
        "id" => "your-match",
        "name" => travel ? "Your Travel #{card_count == 1 ? 'Pick' : 'Stack'}" : "Your Cashback #{card_count == 1 ? 'Pick' : 'Stack'}",
        "description" => travel ?
          "A flexible setup that turns everyday spend into your next trip." :
          "Simple cash rewards across the places you spend most — no points maths.",
        "persona" => "Built from your answers",
        "icon" => travel ? "plane" : "sparkles",
        "cardIds" => @cards.pluck("id")
      }
    end
    @alternatives = @all_cards.reject { |card| @cards.pluck("id").include?(card["id"]) }
  end

  private

  def load_data
    @all_cards = JSON.parse(Rails.root.join("data/cards.json").read)
    @stacks = JSON.parse(Rails.root.join("data/stacks.json").read)
    @cards_by_id = @all_cards.index_by { |card| card["id"] }
  end
end
