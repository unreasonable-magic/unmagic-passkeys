# Changelog

## [Unreleased]

### Added
- `params:` option on `passkey_registration_button` / `passkey_sign_in_button`,
  rendering extra hidden fields inside the ceremony form (like `button_to`'s
  `params:`). The signup example uses it to carry the email through the
  two-phase ceremony.
- README "Host wiring" rewritten around copy-pasteable sign-in, signup, and
  passkey-management controllers (Rails 8 `generate authentication`
  vocabulary). The same controllers live in `spec/dummy` and are exercised end
  to end by the request specs, including a two-phase signup ceremony where
  `find_or_create_by!` makes signup and "existing user enrolling a new device"
  the same flow.

### Removed (breaking)
- The shipped flow controllers and everything that existed to customize them:
  `Unmagic::Passkeys::SessionsController` / `CredentialsController` /
  `ApplicationController`, their views, the `use_unmagic_passkeys` router
  macro, and the `sign_in` / `sign_out` / `current_holder` / `base_controller`
  configuration hooks (plus `Unmagic::Passkeys::ConfigurationError`). They were
  glue around app policy — session handling, redirects, flash copy — behind
  three layers of indirection (hooks, subclassing, view overrides). Copy the
  README's controllers into your app instead; the gem keeps the protocol-shaped
  pieces: the WebAuthn library, `Credential` + `has_passkeys`, the challenge
  endpoint, the `Request` concern, form helpers, JavaScript, and test helpers.

### Changed (breaking)
- Default `routes_prefix` (the challenge endpoint mount point) changed from
  `/unmagic/passkeys` to `/auth/passkeys`. Set
  `config.routes_prefix = "/unmagic/passkeys"` to keep the old URL.

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
