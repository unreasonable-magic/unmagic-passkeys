# frozen_string_literal: true

require "active_support"
require "active_support/all"
require "active_model"
require "openssl"
require "base64"
require "json"
require "digest"

require "unmagic/passkeys/version"
require "unmagic/passkeys/configuration"
require "unmagic/passkeys/web_authn"
require "unmagic/passkeys/holder"
require "unmagic/passkeys/request"
require "unmagic/passkeys/form_helper"
require "unmagic/passkeys/engine" if defined?(::Rails::Engine)

module Unmagic
  # Passkey (WebAuthn) authentication for Rails. The module methods are thin delegators to the
  # +Unmagic::Passkeys::Credential+ Active Record model so host code reads as
  # +Unmagic::Passkeys.authenticate(params)+.
  module Passkeys
    # Raised when a controller flow needs a hook that has not been configured.
    class ConfigurationError < StandardError; end

    class << self
      # The singleton Configuration. Memoized with defaults; mutate via +configure+.
      def configuration
        @configuration ||= Configuration.new
      end

      # Configure the engine in a single block:
      #
      #   Unmagic::Passkeys.configure do |config|
      #     config.relying_party_name = "Shopping"
      #   end
      def configure
        yield configuration
      end

      def registration_options(**options)
        Credential.registration_options(**options)
      end

      def register(passkey, **attributes)
        Credential.register(passkey, **attributes)
      end

      def authentication_options(**options)
        Credential.authentication_options(**options)
      end

      def authenticate(passkey)
        Credential.authenticate(passkey)
      end
    end
  end
end
