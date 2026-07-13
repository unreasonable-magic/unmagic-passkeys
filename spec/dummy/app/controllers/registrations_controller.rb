# The README's copy-paste signup controller, adapted to the dummy app's
# minimal session. Exercised end to end by spec/requests/passkey_flows_spec.rb.
class RegistrationsController < ApplicationController
  include Unmagic::Passkeys::Request

  def new
  end

  # Called twice: with an email it renders the ceremony page; with the
  # attestation it verifies, saves the passkey, and signs the user in.
  def create
    @email = params.expect(registration: [ :email ])[:email]
    user = User.find_or_create_by!(email: @email)

    if params[:passkey].present?
      user.passkeys.register(passkey_registration_params)
      start_new_session_for user
      redirect_to "/"
    else
      @registration_options = passkey_registration_options(holder: user)
      render :create
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to new_registration_path, alert: "Enter a valid email address."
  rescue Unmagic::Passkeys::WebAuthn::InvalidResponseError
    redirect_to new_registration_path, alert: "That didn't work. Try again."
  end
end
