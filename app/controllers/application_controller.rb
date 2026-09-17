class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :claim_quiz_response, if: :user_signed_in?

  helper_method :latest_quiz_response, :draft_quiz_response

  # A missing card, stack or result gets the branded page, in development too.
  # JSON callers (the wallet and chat endpoints) still get a bare 404.
  rescue_from ActiveRecord::RecordNotFound do
    if request.format.symbol.in?(%i[html turbo_stream])
      render "errors/not_found", status: :not_found, formats: :html
    else
      head :not_found
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name ])
  end

  # The quiz can be taken before signing up. The result id is kept in the
  # session so card pages can be personalised. The session lookup is scoped to
  # unclaimed (user_id: nil) responses so a shared computer can never surface
  # one visitor's ranking to the next; signed-in visitors resolve through their
  # own responses instead.
  def latest_quiz_response
    @latest_quiz_response ||= begin
      id = session[:last_quiz_response_id]
      anonymous = QuizResponse.completed.where(id: id, user_id: nil).first if id.present?
      anonymous || current_user&.quiz_responses&.completed&.order(:completed_at)&.last
    end
  end

  # The most recent unfinished quiz belonging to this visitor, which the quiz
  # resumes from and the home page can offer to continue.
  def draft_quiz_response
    @draft_quiz_response ||= current_user&.quiz_responses&.drafts&.order(:updated_at)&.last
  end

  private

  # When a visitor who took the quiz anonymously signs in, attach that result to
  # their account. session.delete clears the key in the same step, so this runs
  # one query on the request right after sign-in rather than on every request.
  def claim_quiz_response
    claim(session.delete(:last_quiz_response_id))
    claim(session.delete(:draft_quiz_response_id))
  end

  def claim(id)
    return if id.blank?

    QuizResponse.where(id: id, user_id: nil).first&.update(user: current_user)
  end
end
