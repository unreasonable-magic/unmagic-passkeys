Rails.application.routes.draw do
  mount Unmagic::Passkeys::Engine => "/unmagic-passkeys"

  resource  :session,      only: %i[new create destroy]
  resource  :registration, only: %i[new create]
  resources :passkeys,     only: %i[index create destroy]
end
