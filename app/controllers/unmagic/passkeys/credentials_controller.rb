# Passkey management for the signed-in holder: list (+index+), add (+create+),
# and remove (+destroy+). Requires authentication via the host's base
# controller. The holder comes from the configured +current_holder+ hook.
class Unmagic::Passkeys::CredentialsController < Unmagic::Passkeys::ApplicationController
  def index
    @passkeys = passkey_holder.passkeys.order(created_at: :desc)
    @registration_options = passkey_registration_options(holder: passkey_holder)
  end

  def create
    passkey_holder.passkeys.register(passkey_registration_params)
    redirect_to url_for(action: :index), notice: "Passkey added."
  end

  def destroy
    passkey_holder.passkeys.find(params[:id]).destroy
    redirect_to url_for(action: :index), notice: "Passkey removed."
  end

  private
    def passkey_holder
      current_passkey_holder or raise Unmagic::Passkeys::ConfigurationError,
        "Unmagic::Passkeys.configure { |c| c.current_holder { ... } } must be set to manage passkeys"
    end
end
