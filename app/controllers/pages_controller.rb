class PagesController < ApplicationController
  def home
    # Featured on the home page. Loaded from real stacks so the cards shown
    # (and their names) always match the catalogue rather than drifting.
    @featured_stacks = Stack.includes(:cards).order(:id).first(3)
  end
end
