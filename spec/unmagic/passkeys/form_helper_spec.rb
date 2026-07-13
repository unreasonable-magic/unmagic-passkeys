# frozen_string_literal: true

require "rails_helper"

RSpec.describe Unmagic::Passkeys::FormHelper, type: :helper do
  it "renders a sign-in button web component with the assertion fields" do
    html = helper.passkey_sign_in_button("Sign in", "/session/passkey", options: { allow: [] })

    expect(html).to include("<unmagic-passkey-sign-in-button")
    expect(html).to include("challenge-url=\"/auth/passkeys/challenge\"")
    expect(html).to include('data-passkey-field="id"')
    expect(html).to include('data-passkey-field="signature"')
  end

  it "renders a registration button web component with the attestation fields" do
    html = helper.passkey_registration_button("Register", "/my/passkeys", options: { user: {} })

    expect(html).to include("<unmagic-passkey-registration-button")
    expect(html).to include('data-passkey-field="attestation_object"')
  end

  it "renders extra params as hidden fields inside the ceremony form" do
    html = helper.passkey_registration_button("Register", "/registration",
      options: { user: {} }, params: { registration: { email: "x@example.com" } })

    expect(html).to include('name="registration[email]"')
    expect(html).to include('value="x@example.com"')
  end
end
