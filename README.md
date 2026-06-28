# Unmagic::Passkeys

Passkey (WebAuthn) authentication for Rails, backed by Active Record, with **no
external dependencies**. The WebAuthn ceremonies — CBOR decoding, COSE key parsing,
attestation and assertion verification — are implemented in pure Ruby on top of
stdlib OpenSSL. Challenges are stateless (signed, expiring tokens), so there's no
server-side challenge storage.

## Provenance

This gem is **extracted from the [`fizzy`](https://github.com/basecamp) codebase**,
where the WebAuthn/passkey implementation lives vendored under `lib/action_pack/` as
`ActionPack::Passkey` / `ActionPack::WebAuthn`. By the looks of it (the `ActionPack::`
namespace, the railtie wiring, the omakase style) it's on its way to becoming a
first-class **Rails** feature eventually.

Until that lands and ships, this is the **extracted, standalone version** — the same
code lifted out, renamed under `Unmagic::Passkeys`, and packaged as a self-contained
Rails engine you can drop into an app today. If/when an official Rails passkeys API
arrives, prefer it; this gem exists to bridge the gap in the meantime.

See `NOTICE` for attribution.

## Installation

```ruby
# Gemfile
gem "unmagic-passkeys"
```

```sh
bin/rails generate unmagic:passkeys:install   # copies the migration, wires the JS
bin/rails db:migrate
```

## Holder model

Declare which model owns passkeys with `has_passkeys`. `name` is the account
identifier shown by the authenticator; `display_name` is a friendly label.

```ruby
class User < ApplicationRecord
  has_passkeys name: :email_address, display_name: :name
end
```

This adds a polymorphic `has_many :passkeys` association and
`passkey_registration_options` / `passkey_authentication_options`.

## API

```ruby
# Registration ceremony
options  = Unmagic::Passkeys.registration_options(holder: user)   # -> pass to navigator.credentials.create()
passkey  = user.passkeys.register(params[:passkey])               # verifies attestation, persists

# Authentication ceremony
options  = Unmagic::Passkeys.authentication_options               # -> pass to navigator.credentials.get()
passkey  = Unmagic::Passkeys.authenticate(params[:passkey])       # verified credential, or nil
```

The engine mounts a stateless challenge endpoint at `POST /unmagic/passkeys/challenge`
(`passkey_challenge_path`), which the JavaScript refreshes before each ceremony.

## Host wiring

Include the JavaScript once — the form helpers render self-contained web components:

```js
// app/javascript/application.js
import "unmagic/passkeys"
```

### Batteries included: `use_unmagic_passkeys`

This draws the multi-user passkey auth flows and points them at the engine's
base controllers:

```ruby
# config/routes.rb
use_unmagic_passkeys
```

| Flow          | Routes                                    | Controller                                |
| ------------- | ----------------------------------------- | ----------------------------------------- |
| `sessions`    | `GET/POST/DELETE /session`, `/session/new`| `Unmagic::Passkeys::SessionsController`    |
| `credentials` | `/my/passkeys` (index/create/destroy)     | `Unmagic::Passkeys::CredentialsController` |

Sign-in is **usernameless** (discoverable credentials), so the one sign-in page
authenticates any user — multi-user out of the box. The controllers are
policy-free; they call **hooks** you configure for the app-specific bits:

```ruby
# config/initializers/passkeys.rb
Unmagic::Passkeys.configure do |config|
  config.base_controller = "ApplicationController"       # so hooks see your helpers

  config.sign_in        { |holder| start_new_session_for(holder) }
  config.sign_out       { terminate_session }
  config.current_holder { Current.user }                 # for /my/passkeys
end
```

Customize by subclassing a base controller and re-pointing the route:

```ruby
# config/routes.rb
use_unmagic_passkeys do
  controllers sessions: "sessions", credentials: "my/passkeys"
  # skip_controllers :credentials
  # scope: "accounts"   # nest everything under a path
end

# app/controllers/sessions_controller.rb
class SessionsController < Unmagic::Passkeys::SessionsController
  rate_limit to: 10, within: 3.minutes
  private def after_passkey_sign_in_path = after_authentication_url
end
```

Each base controller exposes overridable methods for redirects and copy
(`after_passkey_sign_in_path`, `after_passkey_sign_in_failure_path`,
`after_passkey_sign_out_path`, `passkey_sign_in_failure_alert`). The default
`sessions/new` and `credentials/index` views are overridable — drop a file at the
same view path.

### Signup is yours

Account creation is the app's job — the engine authenticates holders, it doesn't
own your user schema. Once you've created/identified a holder, register their
first passkey with the same primitives the management flow uses, then sign them
in:

```ruby
# Already-known holder (invite, email-first, OAuth, single-user bootstrap, …):
@registration_options = Unmagic::Passkeys.registration_options(holder: user)  # -> render for the ceremony
user.passkeys.register(passkey_registration_params)                           # verify + persist
start_new_session_for(user)
```

### À la carte primitives

Prefer to own the controllers? Skip the macro and use the building blocks
directly. `Unmagic::Passkeys::Request` provides `passkey_registration_params`,
`passkey_authentication_params`, `passkey_registration_options`,
`passkey_authentication_options`, and sets `Unmagic::Passkeys::WebAuthn::Current`
(host/origin) per request:

```ruby
class Sessions::PasskeysController < ApplicationController
  include Unmagic::Passkeys::Request

  def create
    if credential = Unmagic::Passkeys.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "That passkey didn't work."
    end
  end
end
```

## Configuration

Configure the engine in a single block:

```ruby
# config/initializers/passkeys.rb
Unmagic::Passkeys.configure do |config|
  config.default_creation_options        = { attestation: :none }
  config.default_request_options         = { user_verification: :required }
  config.creation_challenge_expiration   = 10.minutes
  config.request_challenge_expiration    = 5.minutes

  # Relying party identity (default: request host / Rails.application.name)
  # config.relying_party_id   = "example.com"
  # config.relying_party_name = "Example"

  # config.parent_class_name = "ApplicationRecord"
  # config.routes_prefix     = "/unmagic/passkeys"   # set in config/application.rb if overriding
  # config.draw_routes       = true
end
```

## Testing

Mint valid WebAuthn ceremony payloads without a browser. Requiring the helper
auto-includes it into Rails integration tests:

```ruby
# test/test_helper.rb
require "unmagic/passkeys/test/helpers"

# test/controllers/sessions/passkeys_controller_test.rb
credential = register_passkey_for(@user)
assertion  = in_webauthn_context do
  build_assertion_params(challenge: webauthn_challenge(purpose: "authentication"), credential: credential)
end
post session_passkey_path, params: { passkey: assertion }
```

For RSpec (or any non-integration test), include it yourself:

```ruby
require "unmagic/passkeys/test/helpers"
RSpec.configure { |c| c.include Unmagic::Passkeys::Test::Helpers }
```

It defaults the relying party to `www.example.com` (the integration-test host).
Override `webauthn_rp_id` / `webauthn_origin` in your test class to use another.

## Development

```sh
bundle install
bundle exec rspec    # specs (incl. a full register→authenticate round-trip)
bundle exec rubocop
```

Supported algorithms: ES256 (P-256), EdDSA (Ed25519), RS256. Only the `none`
attestation format is verified by default; register others with
`Unmagic::Passkeys::WebAuthn.register_attestation_verifier`.

## License

MIT — see `LICENSE`. Attribution in `NOTICE`.
