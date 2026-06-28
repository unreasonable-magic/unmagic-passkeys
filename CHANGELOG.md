# Changelog

## [Unreleased]

## [0.2.0] - 2026-06-28

### Added
- Initial extraction: passkey (WebAuthn) registration and authentication for Rails
  as a self-contained engine — pure-Ruby CBOR/COSE/attestation/assertion, stateless
  signed challenges, a `has_passkeys` model macro, form helpers, a challenge
  endpoint, and JavaScript web components. No external dependencies.
- `Unmagic::Passkeys.configure { |config| ... }` block as the single
  configuration entry point, with a memoized `Unmagic::Passkeys.configuration`.
  Adds `relying_party_id` / `relying_party_name` overrides and `base_controller`.
- `use_unmagic_passkeys` router macro that
  draws the multi-user sign-in (`/session`) and management (`/my/passkeys`) flows,
  pointing at subclassable base controllers (`Unmagic::Passkeys::SessionsController`
  / `CredentialsController`) with overridable ERB views. Supports `controllers`,
  `skip_controllers`, and `scope`. App-specific behaviour is injected through
  configuration hooks: `sign_in`, `sign_out`, `current_holder`. Sign-in is
  usernameless (discoverable credentials), so it serves any number of users.
  Account creation (signup) is left to the host app, which registers a passkey
  for a holder it has created with the existing primitives.
- `Unmagic::Passkeys::Test::Helpers` — test helper that mints valid WebAuthn
  ceremony payloads from a fixed key pair (`register_passkey_for`,
  `build_attestation_params`, `build_assertion_params`, `webauthn_challenge`,
  `with_webauthn_request_context`). Requiring `unmagic/passkeys/test/helpers`
  auto-includes it into Rails integration tests; RP id/origin are overridable.

### Changed (breaking)
- Configuration moved off the Rails engine options. The
  `config.unmagic_passkeys.*` (and `config.unmagic_passkeys.web_authn.*`) settings
  are removed entirely — there is no backward-compatible bridge. Migrate to the
  `Unmagic::Passkeys.configure` block (e.g.
  `config.unmagic_passkeys.web_authn.request_challenge_expiration` becomes
  `config.request_challenge_expiration`).
