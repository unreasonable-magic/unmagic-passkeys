# Base controller for the passkey auth flows. Inherits from the host's
# +ApplicationController+ by default (configurable via
# +Unmagic::Passkeys.configuration.base_controller+) so the configured hooks can
# call your app's session helpers, and so the flows pick up your layout.
#
# Your app customizes behaviour by subclassing the concrete controllers
# (SessionsController / CredentialsController) and re-pointing the routes with
# +use_unmagic_passkeys { controllers ... }+.
class Unmagic::Passkeys::ApplicationController < Unmagic::Passkeys.configuration.base_controller.constantize
  include Unmagic::Passkeys::Request

  private
    # Runs the configured +sign_in+ hook in this controller's context.
    def sign_in_holder(holder)
      hook = Unmagic::Passkeys.configuration.sign_in
      unless hook
        raise Unmagic::Passkeys::ConfigurationError,
          "Unmagic::Passkeys.configure { |c| c.sign_in { |holder| ... } } must be set to use the passkey sign-in flows"
      end

      instance_exec(holder, &hook)
    end

    # Runs the configured +sign_out+ hook, if any.
    def sign_out_holder
      hook = Unmagic::Passkeys.configuration.sign_out
      instance_exec(&hook) if hook
    end

    # The signed-in holder, via the configured +current_holder+ hook.
    def current_passkey_holder
      hook = Unmagic::Passkeys.configuration.current_holder
      hook ? instance_exec(&hook) : nil
    end
end
