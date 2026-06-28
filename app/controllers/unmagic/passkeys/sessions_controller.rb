# Passkey sign-in: the sign-in page (+new+), the authentication ceremony
# (+create+), and sign-out (+destroy+).
#
# Sign-in is usernameless — it relies on discoverable credentials, so the same
# page signs in any user. Subclass to add rate limiting or to change the
# redirect targets, then re-point the route:
#
#   class SessionsController < Unmagic::Passkeys::SessionsController
#     rate_limit to: 10, within: 3.minutes
#     private def after_passkey_sign_in_path = after_authentication_url
#   end
class Unmagic::Passkeys::SessionsController < Unmagic::Passkeys::ApplicationController
  # Sign-in must be reachable while signed out. No-op when the base controller
  # has no such callback.
  skip_before_action :require_authentication, raise: false

  def new
    @authentication_options = passkey_authentication_options
  end

  def create
    if credential = Unmagic::Passkeys.authenticate(passkey_authentication_params)
      sign_in_holder(credential.holder)
      redirect_to after_passkey_sign_in_path
    else
      redirect_to after_passkey_sign_in_failure_path, alert: passkey_sign_in_failure_alert
    end
  end

  def destroy
    sign_out_holder
    redirect_to after_passkey_sign_out_path, status: :see_other
  end

  private
    def after_passkey_sign_in_path = "/"
    def after_passkey_sign_in_failure_path = new_session_path
    def after_passkey_sign_out_path = new_session_path
    def passkey_sign_in_failure_alert = "That passkey didn't work. Try again."
end
