class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action { Current.user = User.find_by(id: session[:holder_id]) }

  private
    # Minimal stand-ins for the session helpers a real app gets from
    # `bin/rails generate authentication`.
    def start_new_session_for(user)
      session[:holder_id] = user.id
    end

    def terminate_session
      session.delete(:holder_id)
    end
end
