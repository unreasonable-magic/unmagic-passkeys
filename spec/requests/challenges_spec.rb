# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Passkey challenge endpoint" do
  it "issues a fresh signed challenge" do
    post "/unmagic/passkeys/challenge", params: { purpose: "authentication" }

    expect(response).to have_http_status(:ok)
    challenge = response.parsed_body["challenge"]
    expect(challenge).to be_present

    # The challenge is a Base64URL-wrapped, purpose-scoped signed token.
    verifier = Unmagic::Passkeys::WebAuthn.challenge_verifier
    signed = Base64.urlsafe_decode64(challenge)
    expect(verifier.verified(signed, purpose: "authentication")).to be_present
    expect(verifier.verified(signed, purpose: "registration")).to be_nil
  end
end
