# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passkey registration and authentication ceremony" do
  let(:user) { User.create!(email: "person@example.com") }

  around { |example| with_webauthn_request_context { example.run } }

  it "registers a passkey for a holder and authenticates with it" do
    registration = build_attestation_params(challenge: webauthn_challenge(purpose: "registration"))

    credential = nil
    expect { credential = user.passkeys.register(registration) }
      .to change { Unmagic::Passkeys::Credential.count }.by(1)

    expect(credential.holder).to eq(user)
    expect(credential.credential_id).to be_present
    expect(credential.transports).to eq([ "internal" ])

    assertion = build_assertion_params(challenge: webauthn_challenge(purpose: "authentication"), credential: credential)
    authenticated = Unmagic::Passkeys.authenticate(assertion)

    expect(authenticated).to eq(credential)
    expect(authenticated.sign_count).to eq(1)
  end

  it "rejects an assertion signed for a different challenge value" do
    credential = user.passkeys.register(build_attestation_params(challenge: webauthn_challenge(purpose: "registration")))

    tampered = build_assertion_params(challenge: webauthn_challenge(purpose: "authentication"), credential: credential)
    tampered[:client_data_json] = { challenge: "not-the-signed-one", origin: WebauthnTestHelper::ORIGIN, type: "webauthn.get" }.to_json

    expect(Unmagic::Passkeys.authenticate(tampered)).to be_nil
  end

  it "returns nil for an unknown credential id" do
    expect(Unmagic::Passkeys.authenticate(id: "does-not-exist", client_data_json: "{}",
      authenticator_data: "", signature: "")).to be_nil
  end
end
