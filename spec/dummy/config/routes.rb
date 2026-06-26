Rails.application.routes.draw do
  mount Unmagic::Passkeys::Engine => "/unmagic-passkeys"
end
