class CardsController < ApplicationController
  def index
    @browse_payload = BrowseCatalogue.new.payload
  end

  def show
    @card = Card.find(params[:id])
  end
end
