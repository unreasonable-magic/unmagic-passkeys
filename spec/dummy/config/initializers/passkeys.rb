# Wires the engine's base controllers to a minimal session (a single id stashed
# in the Rails session) so the request specs can exercise the full flows.
Unmagic::Passkeys.configure do |config|
  config.base_controller = "ApplicationController"

  config.sign_in        { |holder| session[:holder_id] = holder.id }
  config.sign_out       { session.delete(:holder_id) }
  config.current_holder { User.find_by(id: session[:holder_id]) }
end
