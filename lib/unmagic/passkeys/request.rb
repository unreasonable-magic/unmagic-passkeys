# = Action Pack Passkey Request
#
# Controller concern that sets up the WebAuthn request context and provides
# helper methods for passkey registration and authentication. Include this
# in any controller that handles passkey form submissions.
#
# == Registration example
#
#   class PasskeysController < ApplicationController
#     include Unmagic::Passkeys::Request
#
#     def new
#       @registration_options = passkey_registration_options(holder: Current.user)
#     end
#
#     def create
#       @passkey = Unmagic::Passkeys::Credential.register(
#         passkey_registration_params, holder: Current.user
#       )
#       redirect_to settings_path
#     end
#   end
#
# == Authentication example
#
#   class SessionsController < ApplicationController
#     include Unmagic::Passkeys::Request
#
#     def new
#       @authentication_options = passkey_authentication_options
#     end
#
#     def create
#       if passkey = Unmagic::Passkeys::Credential.authenticate(passkey_authentication_params)
#         sign_in passkey.holder
#         redirect_to root_path
#       else
#         redirect_to new_session_path, alert: "Authentication failed"
#       end
#     end
#   end
#
# == Before Action
#
# Automatically populates +Unmagic::Passkeys::WebAuthn::Current+ with the request
# host and origin.
#
module Unmagic::Passkeys::Request
  extend ActiveSupport::Concern

  included do
    before_action do
      Unmagic::Passkeys::WebAuthn::Current.host = request.host
      Unmagic::Passkeys::WebAuthn::Current.origin = request.base_url
    end
  end

  # Returns strong parameters for the passkey registration ceremony.
  def passkey_registration_params(param: :passkey)
    params.expect(param => [ :client_data_json, :attestation_object, transports: [] ])
  end

  # Returns strong parameters for the passkey authentication ceremony.
  def passkey_authentication_params(param: :passkey)
    params.expect(param => [ :id, :client_data_json, :authenticator_data, :signature ])
  end

  # Returns RequestOptions for the authentication ceremony.
  def passkey_authentication_options(**options)
    Unmagic::Passkeys::Credential.authentication_options(**options)
  end

  # Returns RegistrationOptions for the registration ceremony.
  def passkey_registration_options(**options)
    Unmagic::Passkeys::Credential.registration_options(**options)
  end
end
