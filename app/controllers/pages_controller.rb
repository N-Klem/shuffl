class PagesController < ApplicationController
  def home
    # Three-card stacks share one consistent homepage fan. Smaller stacks
    # remain available in Browse.
    @featured_stacks = Stack.available.includes(:cards, stack_cards: :card).order(:id).select { |stack| stack.cards.size == 3 }.first(3)
  end
end
