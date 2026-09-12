class WalletItemsController < ApplicationController
  before_action :authenticate_user!, except: :save_stack

  def index
    @wallet_payload = WalletDashboard.new(current_user).payload
  end

  def create
    wallet_item = current_user.wallet_items.new(card_id: params[:card_id])

    if wallet_item.save
      return render json: WalletDashboard.new(current_user).payload if request.format.json?
      redirect_back fallback_location: root_path, notice: "Card added to your wallet."
    else
      return render json: { error: wallet_item.errors.full_messages.to_sentence }, status: :unprocessable_entity if request.format.json?
      redirect_back fallback_location: root_path, alert: "Couldn't add that card to your wallet."
    end
  end

  def update
    item = current_user.wallet_items.find(params[:id])
    permitted = params.require(:wallet_item).permit(:status, :opened_on, :apply_on, :payment_due_on,
      :bonus_deadline, :statement_balance, :bonus_spend, :bonus_target, :paid)
    if params[:wallet_item][:card_id].present?
      return render json: { error: "Only planned cards can be swapped." }, status: :unprocessable_entity unless item.status == "planned"
      permitted[:card_id] = Card.find(params[:wallet_item][:card_id]).id
    end
    if item.update(permitted)
      render json: WalletDashboard.new(current_user).payload
    else
      render json: { error: item.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def preferences
    settings = params.require(:preferences).permit(:notifications, amounts: [])
    if settings[:amounts]
      values = settings[:amounts].map { |value| Float(value) rescue -1 }
      unless values.size == 6 && values.all? { |value| value.finite? && value.between?(0, 1_000_000) }
        return render json: { error: "Enter six valid spending amounts." }, status: :unprocessable_entity
      end
      settings[:amounts] = values
    end
    current_user.with_lock do
      current_user.update!(wallet_preferences: current_user.wallet_preferences.merge(settings.to_h))
    end
    render json: WalletDashboard.new(current_user).payload
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
