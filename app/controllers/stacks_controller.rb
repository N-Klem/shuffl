class StacksController < ApplicationController
  def index
    redirect_to cards_path(tab: "stacks")
  end

  def show
    @stack = Stack.find(params[:id])
  end
end
