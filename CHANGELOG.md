# Changelog

## [Unreleased]

### Added
- Initial extraction: passkey (WebAuthn) registration and authentication for Rails
  as a self-contained engine — pure-Ruby CBOR/COSE/attestation/assertion, stateless
  signed challenges, a `has_passkeys` model macro, form helpers, a challenge
  endpoint, and JavaScript web components. No external dependencies.
