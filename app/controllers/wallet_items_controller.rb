class WalletItemsController < ApplicationController
  before_action :authenticate_user!

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

  def destroy
    wallet_item = current_user.wallet_items.find(params[:id])
    wallet_item.destroy
    redirect_back fallback_location: wallet_items_path, notice: "Card removed from your wallet."
  end
end
