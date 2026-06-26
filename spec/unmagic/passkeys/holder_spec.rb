# frozen_string_literal: true

require "rails_helper"

RSpec.describe Unmagic::Passkeys::Holder do
  let(:user) { User.create!(email: "person@example.com") }

  around { |example| with_webauthn_request_context { example.run } }

  it "adds a passkeys association to the holder" do
    expect(user.passkeys).to be_empty
    expect(user.passkeys.build).to be_a(Unmagic::Passkeys::Credential)
  end

  it "exposes the holder's name and display name as registration options" do
    options = user.passkey_registration_options
    expect(options[:name]).to eq(user.email)
    expect(options[:display_name]).to eq(user.email)
  end

  it "scopes existing credentials into authentication options" do
    credential = user.passkeys.register(build_attestation_params(challenge: webauthn_challenge(purpose: "registration")))
    expect(user.passkey_authentication_options[:credentials]).to include(credential)
  end
end
