# = Action Pack Passkey Challenges Controller
#
# Generates fresh WebAuthn challenges for passkey ceremonies. The companion
# JavaScript calls this endpoint before initiating a registration or
# authentication ceremony so that the challenge is issued just-in-time rather
# than embedded in the initial page load.
#
# The generated challenge is returned in the JSON response body. The challenge
# is a signed, expiring token that the server can verify on the subsequent
# form submission without needing server-side state — the challenge is
# extracted from the authenticator's +clientDataJSON+ response.
#
# == Route
#
# By default mounted at +/auth/passkeys/challenge+ (configurable via
# +Unmagic::Passkeys.configuration.routes_prefix+).
#
class Unmagic::Passkeys::ChallengesController < ActionController::Base
  include Unmagic::Passkeys::Request

  # Generates a fresh challenge and returns it as JSON. Accepts an optional
  # +purpose+ parameter ("registration" or "authentication") to select the
  # appropriate challenge expiration. Defaults to "authentication".
  def create
    render json: { challenge: create_passkey_challenge }
  end

  private
    def create_passkey_challenge
      Unmagic::Passkeys::WebAuthn::PublicKeyCredential::Options.new(
        challenge_expiration: challenge_expiration,
        challenge_purpose: challenge_purpose
      ).challenge
    end

    def challenge_purpose
      params[:purpose] == "registration" ? "registration" : "authentication"
    end

    def challenge_expiration
      config = Unmagic::Passkeys.configuration

      if challenge_purpose == "registration"
        config.creation_challenge_expiration
      else
        config.request_challenge_expiration
      end
    end
end
