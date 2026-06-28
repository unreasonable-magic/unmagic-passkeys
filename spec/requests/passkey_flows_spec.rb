# frozen_string_literal: true

require "rails_helper"

# Exercises the controllers mounted by use_unmagic_passkeys end to end. The
# request host is www.example.com, which matches the test helper's relying
# party, so payloads minted by the helper verify against the live request
# context the controllers set up.
RSpec.describe "Passkey flows" do
  let!(:user) { User.create!(email: "owner@example.com") }

  def registration_params
    build_attestation_params(challenge: webauthn_challenge(purpose: "registration"))
  end

  def assertion_params(credential)
    build_assertion_params(challenge: webauthn_challenge(purpose: "authentication"), credential: credential)
  end

  describe "sign-in page" do
    it "renders the usernameless sign-in button" do
      get "/session/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("unmagic-passkey-sign-in-button")
    end
  end

  describe "sign-in" do
    it "authenticates a registered passkey and starts a session" do
      credential = register_passkey_for(user)

      post "/session", params: { passkey: assertion_params(credential) }

      expect(response).to be_redirect
      expect(session[:holder_id]).to eq(user.id)
    end

    it "signs each user into their own account from one shared page (multi-user)" do
      other = User.create!(email: "other@example.com")
      user_credential = register_passkey_for(user)
      other_credential = register_passkey_for(other)

      post "/session", params: { passkey: assertion_params(other_credential) }
      expect(session[:holder_id]).to eq(other.id)

      reset!  # fresh session/cookies

      post "/session", params: { passkey: assertion_params(user_credential) }
      expect(session[:holder_id]).to eq(user.id)
    end

    it "redirects back to the sign-in page when authentication fails" do
      register_passkey_for(user)
      bad = assertion_params(user.passkeys.first)
      bad[:signature] = Base64.urlsafe_encode64("tampered", padding: false)

      post "/session", params: { passkey: bad }

      expect(response).to redirect_to("/session/new")
      expect(session[:holder_id]).to be_nil
    end
  end

  describe "management" do
    before { register_passkey_for(user) }

    def sign_in!
      post "/session", params: { passkey: assertion_params(user.passkeys.first) }
    end

    it "lists the holder's passkeys" do
      sign_in!

      get "/my/passkeys"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(user.passkeys.first))
    end

    it "adds a passkey" do
      sign_in!

      expect {
        post "/my/passkeys", params: { passkey: registration_params }
      }.to change { user.passkeys.count }.by(1)

      expect(response).to redirect_to("/my/passkeys")
    end

    it "removes a passkey" do
      sign_in!
      passkey = user.passkeys.first

      expect {
        delete "/my/passkeys/#{passkey.id}"
      }.to change { user.passkeys.count }.by(-1)

      expect(response).to redirect_to("/my/passkeys")
    end
  end

  describe "sign-out" do
    it "clears the session" do
      credential = register_passkey_for(user)
      post "/session", params: { passkey: assertion_params(credential) }
      expect(session[:holder_id]).to eq(user.id)

      delete "/session"

      expect(response).to be_redirect
      expect(session[:holder_id]).to be_nil
    end
  end
end
