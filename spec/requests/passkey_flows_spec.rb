# frozen_string_literal: true

require "rails_helper"

# Exercises the dummy app's copy of the README's copy-paste controllers end to
# end, proving the documented examples actually work. The request host is
# www.example.com, which matches the test helper's relying party, so payloads
# minted by the helper verify against the live request context the controllers
# set up.
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

      get "/passkeys"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(user.passkeys.first))
    end

    it "adds a passkey" do
      sign_in!

      expect {
        post "/passkeys", params: { passkey: registration_params }
      }.to change { user.passkeys.count }.by(1)

      expect(response).to redirect_to("/passkeys")
    end

    it "removes a passkey" do
      sign_in!
      passkey = user.passkeys.first

      expect {
        delete "/passkeys/#{passkey.id}"
      }.to change { user.passkeys.count }.by(-1)

      expect(response).to redirect_to("/passkeys")
    end
  end

  describe "signup" do
    it "renders the identifier form" do
      get "/registration/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="registration[email]"))
    end

    it "resolves the holder and renders the ceremony page with the identifier carried along" do
      expect {
        post "/registration", params: { registration: { email: "new@example.com" } }
      }.to change { User.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("unmagic-passkey-registration-button")
      expect(response.body).to include(%(name="registration[email]"))
      expect(response.body).to include("new@example.com")
    end

    it "registers the passkey and signs the holder in" do
      post "/registration", params: { registration: { email: "new@example.com" }, passkey: registration_params }

      holder = User.find_by!(email: "new@example.com")
      expect(holder.passkeys.count).to eq(1)
      expect(session[:holder_id]).to eq(holder.id)
      expect(response).to be_redirect
    end

    it "reuses the holder created in the identifier phase (find-or-create)" do
      post "/registration", params: { registration: { email: "new@example.com" } }

      expect {
        post "/registration", params: { registration: { email: "new@example.com" }, passkey: registration_params }
      }.not_to change { User.count }

      expect(User.find_by!(email: "new@example.com").passkeys.count).to eq(1)
    end

    it "redirects back when the email is invalid" do
      post "/registration", params: { registration: { email: "" } }

      expect(response).to redirect_to("/registration/new")
    end

    it "redirects back when the attestation is invalid" do
      bad = build_attestation_params(challenge: webauthn_challenge(purpose: "authentication"))

      post "/registration", params: { registration: { email: "new@example.com" }, passkey: bad }

      expect(response).to redirect_to("/registration/new")
      expect(session[:holder_id]).to be_nil
      expect(User.find_by!(email: "new@example.com").passkeys.count).to eq(0)
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
