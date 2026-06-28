Rails.application.routes.draw do
  mount Unmagic::Passkeys::Engine => "/unmagic-passkeys"

  use_unmagic_passkeys
end
