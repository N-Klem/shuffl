class WalletItemsController < ApplicationController
  before_action :authenticate_user!, except: :save_stack

  def index
    @wallet_items = current_user.wallet_items.includes(:card)
  end

  def create
    wallet_item = current_user.wallet_items.new(card_id: params[:card_id])

    if wallet_item.save
      redirect_back fallback_location: root_path, notice: "Card added to your wallet."
    else
      redirect_back fallback_location: root_path, alert: "Couldn't add that card to your wallet."
    end
  end

  def save_stack
    quiz = QuizResponse.find(params[:quiz_response_id])
    unless user_signed_in?
      store_location_for(:user, quiz_response_path(quiz))
      return render json: { sign_in_url: new_user_session_path }, status: :unauthorized
    end

    ids = Array(params[:card_ids]).map(&:to_s).uniq
    cards = Card.where(id: ids)
    unless ids.size.between?(1, 5) && cards.size == ids.size
      return render json: { error: "Choose between one and five available cards." }, status: :unprocessable_entity
    end

    current_user.with_lock do
      cards.each { |card| current_user.wallet_items.find_or_create_by!(card: card) }
    end
    render json: { wallet_url: wallet_items_path }
  end

  def destroy
    wallet_item = current_user.wallet_items.find(params[:id])
    wallet_item.destroy
    redirect_back fallback_location: wallet_items_path, notice: "Card removed from your wallet."
  end
end
