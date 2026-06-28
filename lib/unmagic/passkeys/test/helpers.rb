# frozen_string_literal: true

require "openssl"
require "base64"
require "json"
require "digest"
require "securerandom"

module Unmagic
  module Passkeys
    module Test
      # Mints valid WebAuthn ceremony payloads from a fixed EC P-256 key pair, so
      # passkey registration and authentication can be exercised end to end
      # without a browser. Ported from fizzy's test helper.
      #
      # In a Rails app, requiring this file auto-includes it into integration
      # tests. Elsewhere (e.g. RSpec) include it yourself:
      #
      #   require "unmagic/passkeys/test/helpers"
      #   RSpec.configure { |c| c.include Unmagic::Passkeys::Test::Helpers }
      #
      # The relying party defaults to "www.example.com" / "http://www.example.com"
      # (the Rails integration-test host, so the engine's request context lines up
      # automatically). Override +webauthn_rp_id+ / +webauthn_origin+ in your test
      # class to test under a different host.
      module Helpers
        WEBAUTHN_PRIVATE_KEY = OpenSSL::PKey::EC.new(
          [ "307702010104201dd589de7210b3318620f32150e3012cce021519df1d6e9e01" \
            "0471146d395cdca00a06082a8648ce3d030107a14403420004116847fe19e1ad" \
            "4471ab9980d7ff9cc1e4c7cb7a3af00e082b64fcd84f5ae70114c2495eef16f" \
            "542b5e57dd1b263661624e3cf28f581b57a441edbd756a41d0e" ].pack("H*")
        )

        # Pre-encoded COSE EC2/ES256 public key (CBOR) for the key above.
        COSE_PUBLIC_KEY = [ "a5010203262001215820116847fe19e1ad4471ab9980d7ff9cc1" \
          "e4c7cb7a3af00e082b64fcd84f5ae70122582014c2495eef16f542b5e57dd1b2" \
          "63661624e3cf28f581b57a441edbd756a41d0e" ].pack("H*")

        # CBOR prefix for {"fmt": "none", "attStmt": {}, "authData": bytes(164)}.
        ATTESTATION_OBJECT_CBOR_PREFIX =
          [ "a363666d74646e6f6e656761747453746d74a068617574684461746158a4" ].pack("H*")

        RP_ID = "www.example.com"
        ORIGIN = "http://www.example.com"

        # The relying party identity used to mint payloads. Override in a test
        # class to exercise a different host.
        def webauthn_rp_id = RP_ID
        def webauthn_origin = ORIGIN

        # Registers a passkey for +holder+ directly (used to set up the
        # "already enrolled" state). Returns the persisted credential.
        def register_passkey_for(holder)
          with_webauthn_request_context do
            holder.passkeys.register(build_attestation_params(challenge: webauthn_challenge(purpose: "registration")))
          end
        end

        def with_webauthn_request_context
          Unmagic::Passkeys::WebAuthn::Current.host = webauthn_rp_id
          Unmagic::Passkeys::WebAuthn::Current.origin = webauthn_origin
          yield
        ensure
          Unmagic::Passkeys::WebAuthn::Current.reset
        end
        alias_method :in_webauthn_context, :with_webauthn_request_context

        def webauthn_challenge(purpose: nil)
          Unmagic::Passkeys::WebAuthn::PublicKeyCredential::Options.new(challenge_purpose: purpose).challenge
        end

        def build_attestation_params(challenge:)
          credential_id = SecureRandom.random_bytes(32)
          auth_data = build_attestation_auth_data(credential_id: credential_id)

          {
            client_data_json: webauthn_client_data_json(challenge: challenge, type: "webauthn.create"),
            attestation_object: Base64.urlsafe_encode64(ATTESTATION_OBJECT_CBOR_PREFIX + auth_data, padding: false),
            transports: [ "internal" ]
          }
        end

        def build_assertion_params(challenge:, credential:, sign_count: 1)
          client_data_json = webauthn_client_data_json(challenge: challenge, type: "webauthn.get")
          authenticator_data = build_assertion_auth_data(sign_count: sign_count)
          signature = webauthn_sign(authenticator_data, client_data_json)

          {
            id: credential.credential_id,
            client_data_json: client_data_json,
            authenticator_data: Base64.urlsafe_encode64(authenticator_data, padding: false),
            signature: Base64.urlsafe_encode64(signature, padding: false)
          }
        end

        private
          def webauthn_client_data_json(challenge:, type:)
            { challenge: challenge, origin: webauthn_origin, type: type }.to_json
          end

          def build_attestation_auth_data(credential_id:)
            [
              Digest::SHA256.digest(webauthn_rp_id),
              [ 0x45 ].pack("C"),                       # flags: UP + UV + AT
              [ 0 ].pack("N"),                          # sign_count
              "\x00" * 16,                            # aaguid
              [ credential_id.bytesize ].pack("n"),     # credential_id_length
              credential_id,
              COSE_PUBLIC_KEY
            ].join.b
          end

          def build_assertion_auth_data(sign_count:)
            [
              Digest::SHA256.digest(webauthn_rp_id),
              [ 0x05 ].pack("C"),                       # flags: UP + UV
              [ sign_count ].pack("N")
            ].join.b
          end

          def webauthn_sign(authenticator_data, client_data_json)
            signed_data = authenticator_data + Digest::SHA256.digest(client_data_json)
            WEBAUTHN_PRIVATE_KEY.sign("SHA256", signed_data)
          end
      end
    end
  end
end

# Auto-include into Rails integration tests when Active Support is present.
if defined?(ActiveSupport)
  ActiveSupport.on_load(:action_dispatch_integration_test) do
    include Unmagic::Passkeys::Test::Helpers
  end
end
