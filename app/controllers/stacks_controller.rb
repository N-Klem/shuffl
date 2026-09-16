class StacksController < ApplicationController
  def index
    redirect_to cards_path(tab: "stacks")
  end

  def show
    @stack = Stack.includes(stack_cards: :card).find(params[:id])
    @available = Stack.available.exists?(@stack.id)
  end
end
