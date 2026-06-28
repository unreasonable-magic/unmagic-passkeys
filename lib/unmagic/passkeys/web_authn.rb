# = Action Pack WebAuthn
#
# Provides a pure-Ruby implementation of the WebAuthn (Web Authentication)
# specification for passkey registration and authentication. This module
# is the top-level namespace for all WebAuthn components and provides
# shared utilities used across ceremonies.
#
# == Components
#
# [Unmagic::Passkeys::WebAuthn::RelyingParty]
#   Identifies your application to authenticators.
#
# [Unmagic::Passkeys::WebAuthn::PublicKeyCredential]
#   Orchestrates registration and authentication ceremonies.
#
# [Unmagic::Passkeys::WebAuthn::Authenticator]
#   Parses and validates authenticator responses.
#
# [Unmagic::Passkeys::WebAuthn::CborDecoder]
#   Decodes CBOR-encoded data from authenticators.
#
# [Unmagic::Passkeys::WebAuthn::CoseKey]
#   Parses COSE public keys into OpenSSL key objects.
#
# == Extending Attestation Formats
#
# By default only the "none" attestation format is supported. Register
# additional verifiers with:
#
#   Unmagic::Passkeys::WebAuthn.register_attestation_verifier("packed", MyPackedVerifier.new)
#
module Unmagic::Passkeys::WebAuthn
  class InvalidResponseError < StandardError; end
  class InvalidCborError < StandardError; end
  class InvalidKeyError < StandardError; end
  class UnsupportedKeyTypeError < StandardError; end
  class InvalidOptionsError < StandardError; end

  class << self
    # Returns a new RelyingParty. Identity comes from +Unmagic::Passkeys.configuration+
    # when set, otherwise falls back to the current request host and
    # +Rails.application.name+.
    def relying_party
      config = Unmagic::Passkeys.configuration

      RelyingParty.new(
        id: config.relying_party_id || Current.host,
        name: config.relying_party_name || Rails.application.name
      )
    end

    # Returns the MessageVerifier used to sign and verify WebAuthn challenges.
    def challenge_verifier
      Rails.application.message_verifier("action_pack.webauthn.challenge")
    end

    # Returns the registry of attestation format verifiers, keyed by format
    # string (e.g., "none", "packed"). Only "none" is registered by default.
    def attestation_verifiers
      @attestation_verifiers ||= {
        "none" => Authenticator::AttestationVerifiers::None.new
      }
    end

    # Registers a custom attestation verifier for the given +format+.
    # The +verifier+ must respond to +verify!(attestation, client_data_json:)+.
    def register_attestation_verifier(format, verifier)
      attestation_verifiers[format.to_s] = verifier
    end
  end

  # Implicit namespaces for the ceremony files required below (no Zeitwerk in lib/).
  module Authenticator
    module AttestationVerifiers; end
  end
end

require_relative "web_authn/current"
require_relative "web_authn/relying_party"
require_relative "web_authn/cbor_decoder"
require_relative "web_authn/cose_key"
require_relative "web_authn/public_key_credential"
require_relative "web_authn/public_key_credential/options"
require_relative "web_authn/public_key_credential/creation_options"
require_relative "web_authn/public_key_credential/request_options"
require_relative "web_authn/authenticator/response"
require_relative "web_authn/authenticator/data"
require_relative "web_authn/authenticator/attestation"
require_relative "web_authn/authenticator/attestation_verifiers/none"
require_relative "web_authn/authenticator/attestation_response"
require_relative "web_authn/authenticator/assertion_response"
