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

The engine ships the primitives; your app owns the login/registration controllers and
views. The form helpers render self-contained web components — include the JS once:

```js
// app/javascript/application.js
import "unmagic/passkeys"
```

**Sign in** (`app/views/sessions/new.html.erb`):

```erb
<%= passkey_sign_in_button "Sign in with a passkey", session_passkey_path,
      options: @authentication_options, mediation: "conditional" %>
```

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

**Register** (signed-in):

```erb
<%= passkey_registration_button "Register a passkey", passkeys_path,
      options: @registration_options %>
```

```ruby
class PasskeysController < ApplicationController
  include Unmagic::Passkeys::Request   # sets the WebAuthn request context + param helpers

  def index
    @registration_options = passkey_registration_options(holder: Current.user)
  end

  def create
    Current.user.passkeys.register(passkey_registration_params)
    redirect_to passkeys_path, notice: "Passkey added."
  end
end
```

`Unmagic::Passkeys::Request` provides `passkey_registration_params`,
`passkey_authentication_params`, `passkey_registration_options`,
`passkey_authentication_options`, and sets `Unmagic::Passkeys::WebAuthn::Current`
(host/origin) per request.

## Configuration

```ruby
# config/initializers/passkeys.rb
Rails.application.configure do
  config.unmagic_passkeys.web_authn.default_creation_options = { attestation: :none }
  config.unmagic_passkeys.web_authn.default_request_options  = { user_verification: :required }
  config.unmagic_passkeys.web_authn.creation_challenge_expiration = 10.minutes
  config.unmagic_passkeys.web_authn.request_challenge_expiration  = 5.minutes
  # config.unmagic_passkeys.parent_class_name = "ApplicationRecord"
end
```

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
