class ErrorsController < ApplicationController
  def not_found
    render :not_found, status: :not_found
  end

  def internal_error
    render :internal_error, status: :internal_server_error
  end
end
