# The README's copy-paste sign-in controller, adapted to the dummy app's
# minimal session. Exercised end to end by spec/requests/passkey_flows_spec.rb.
class SessionsController < ApplicationController
  include Unmagic::Passkeys::Request

  def new
    @authentication_options = passkey_authentication_options
  end

  def create
    if credential = Unmagic::Passkeys.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder
      redirect_to "/"
    else
      redirect_to new_session_path, alert: "That passkey didn't work. Try again."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
