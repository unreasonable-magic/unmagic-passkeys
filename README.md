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

The engine mounts a stateless challenge endpoint at `POST /auth/passkeys/challenge`
(`passkey_challenge_path`), which the JavaScript refreshes before each ceremony.

## Host wiring

The gem ships the WebAuthn machinery — the ceremonies, the model, the form
helpers, the JavaScript, and the challenge endpoint. The controllers are
yours: copy the examples below into your app and edit them to fit. (They use
the vocabulary of `bin/rails generate authentication`:
`start_new_session_for`, `terminate_session`, `Current.user`.)

Include the JavaScript once — the form helpers render self-contained web components:

```js
// app/javascript/application.js
import "unmagic/passkeys"
```

Draw the routes:

```ruby
# config/routes.rb
resource  :session,      only: %i[new create destroy]
resource  :registration, only: %i[new create]
resources :passkeys,     only: %i[index create destroy]
```

### Sign-in

Usernameless (discoverable credentials) — one page signs in any user, and
conditional mediation offers passkeys through autofill:

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  include Unmagic::Passkeys::Request

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @authentication_options = passkey_authentication_options
  end

  def create
    if credential = Unmagic::Passkeys.authenticate(passkey_authentication_params)
      start_new_session_for credential.holder
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "That passkey didn't work. Try again."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
```

```erb
<%# app/views/sessions/new.html.erb %>
<p>Sign in with your passkey.</p>
<%= passkey_sign_in_button "Sign in with a passkey", session_path,
      options: @authentication_options, mediation: "conditional" %>
```

### Signup

The ceremony runs in two phases through one `create` action: submitted with an
email it renders the ceremony page (the email rides along via the form
helper's `params:` option); submitted with the attestation it verifies, saves
the passkey, and signs the user in. `find_or_create_by!` makes the two phases
idempotent — and makes signup and "existing user enrolling a new device" the
same flow:

```ruby
# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  include Unmagic::Passkeys::Request

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
  end

  # Called twice: with an email it renders the ceremony page; with the
  # attestation it verifies, saves the passkey, and signs the user in.
  def create
    @email = params.expect(registration: [ :email ])[:email]
    user = User.find_or_create_by!(email_address: @email)
    # TODO: verify the visitor owns @email before handing back an existing
    # account (emailed code, invite token, …) — otherwise a stranger can add
    # a passkey to it.

    if params[:passkey].present?
      user.passkeys.register(passkey_registration_params)
      start_new_session_for user
      redirect_to root_path
    else
      @registration_options = passkey_registration_options(holder: user)
      render :create
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to new_registration_path, alert: "Enter a valid email address."
  rescue Unmagic::Passkeys::WebAuthn::InvalidResponseError
    redirect_to new_registration_path, alert: "That didn't work. Try again."
  end
end
```

```erb
<%# app/views/registrations/new.html.erb %>
<p>Create your account.</p>
<%= form_with scope: :registration, url: registration_path do |form| %>
  <%= form.email_field :email, required: true, autocomplete: "email" %>
  <%= form.submit "Continue" %>
<% end %>
```

```erb
<%# app/views/registrations/create.html.erb %>
<p>Secure your account with a passkey.</p>
<%= passkey_registration_button "Create a passkey", registration_path,
      options: @registration_options, params: { registration: { email: @email } } %>
```

Two things the example leaves to you: **identifier ownership** (nothing above
proves the visitor owns the email they typed) and **abandoned signups** (the
user row is created in the email phase; retries reuse it, sweep the
passkey-less ones if you care).

### Managing passkeys

```ruby
# app/controllers/passkeys_controller.rb
class PasskeysController < ApplicationController
  include Unmagic::Passkeys::Request

  def index
    @passkeys = Current.user.passkeys.order(created_at: :desc)
    @registration_options = passkey_registration_options(holder: Current.user)
  end

  def create
    Current.user.passkeys.register(passkey_registration_params)
    redirect_to passkeys_path, notice: "Passkey added."
  end

  def destroy
    Current.user.passkeys.find(params[:id]).destroy
    redirect_to passkeys_path, notice: "Passkey removed."
  end
end
```

```erb
<%# app/views/passkeys/index.html.erb %>
<ul>
  <% @passkeys.each do |passkey| %>
    <li id="<%= dom_id(passkey) %>">
      <%= passkey.name.presence || "Passkey" %> — added <%= passkey.created_at.to_date.to_fs(:long) %>
      <%= button_to "Remove", passkey_path(passkey), method: :delete %>
    </li>
  <% end %>
</ul>
<%= passkey_registration_button "Add a passkey", passkeys_path,
      options: @registration_options %>
```

These controllers live in `spec/dummy`, where the request specs exercise them
end to end.

### The building blocks

`Unmagic::Passkeys::Request` provides the ceremony strong parameters
(`passkey_registration_params`, `passkey_authentication_params`), the option
builders (`passkey_registration_options`, `passkey_authentication_options`),
and sets `Unmagic::Passkeys::WebAuthn::Current` (host/origin) per request.
`passkey_sign_in_button` / `passkey_registration_button` render web components
that refresh the challenge, run the browser ceremony, and submit the result;
their `params:` option renders extra hidden fields into the ceremony form
(like `button_to`'s).

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
  # config.routes_prefix     = "/auth/passkeys"      # set in config/application.rb if overriding
  # config.draw_routes       = true
end
```

## Testing

Mint valid WebAuthn ceremony payloads without a browser. Requiring the helper
auto-includes it into Rails integration tests:

```ruby
# test/test_helper.rb
require "unmagic/passkeys/test/helpers"

# test/integration/passkey_sign_in_test.rb
credential = register_passkey_for(@user)
assertion  = in_webauthn_context do
  build_assertion_params(challenge: webauthn_challenge(purpose: "authentication"), credential: credential)
end
post session_path, params: { passkey: assertion }
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
