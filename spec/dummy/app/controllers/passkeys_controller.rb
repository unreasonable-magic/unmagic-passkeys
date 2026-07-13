# The README's copy-paste passkey management controller. Exercised end to end
# by spec/requests/passkey_flows_spec.rb.
class PasskeysController < ApplicationController
  include Unmagic::Passkeys::Request

  def index
    @passkeys = Current.user.passkeys.order(created_at: :desc)
    @registration_options = passkey_registration_options(holder: Current.user)
  end

  def create
    Current.user.passkeys.register(passkey_registration_params)
    redirect_to passkeys_path, notice: "Passkey added."
  end

  def destroy
    Current.user.passkeys.find(params[:id]).destroy
    redirect_to passkeys_path, notice: "Passkey removed."
  end
end
