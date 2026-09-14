class PagesController < ApplicationController
  def home
    # Featured on the home page. Loaded from real stacks so the cards shown
    # (and their names) always match the catalogue rather than drifting.
    # Only stacks that actually have cards — an empty fan would break the
    # carousel, which indexes into its card list.
    @featured_stacks = Stack.includes(:cards).order(:id).select { |stack| stack.cards.any? }.first(3)
  end
end
