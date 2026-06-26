# frozen_string_literal: true

module Unmagic
  module Passkeys
    # Integrates the WebAuthn and passkey subsystems into a host Rails app. We deliberately do
    # NOT isolate_namespace: passkeys is an injected concern — +has_passkeys+ goes onto the host's
    # models, the form helpers into its views, and a stateless challenge endpoint into its routes.
    #
    # == Configuration
    #
    #   # config/initializers/passkeys.rb
    #   config.unmagic_passkeys.web_authn.default_creation_options = { attestation: :none }
    #   config.unmagic_passkeys.web_authn.default_request_options  = { user_verification: :required }
    #   config.unmagic_passkeys.routes_prefix = "/unmagic/passkeys"
    class Engine < ::Rails::Engine
      config.unmagic_passkeys = ActiveSupport::OrderedOptions.new
      config.unmagic_passkeys.parent_class_name = "ApplicationRecord"
      config.unmagic_passkeys.routes_prefix = "/unmagic/passkeys"
      config.unmagic_passkeys.draw_routes = true
      config.unmagic_passkeys.challenge_url = nil

      config.unmagic_passkeys.web_authn = ActiveSupport::OrderedOptions.new
      config.unmagic_passkeys.web_authn.default_request_options = {}
      config.unmagic_passkeys.web_authn.default_creation_options = {}
      config.unmagic_passkeys.web_authn.creation_challenge_expiration = 10.minutes
      config.unmagic_passkeys.web_authn.request_challenge_expiration = 5.minutes

      initializer "unmagic_passkeys.routes" do |app|
        passkey_config = config.unmagic_passkeys

        app.routes.prepend do
          if passkey_config.draw_routes
            scope passkey_config.routes_prefix, as: :passkey do
              post "/challenge" => "unmagic/passkeys/challenges#create", as: :challenge
            end
          end
        end
      end

      initializer "unmagic_passkeys.holder" do
        ActiveSupport.on_load(:active_record) do
          # Shim: Holder references the Credential model (itself Active Record), so it can't be
          # mixed in until Active Record is ready. The first call swaps in the real macro.
          def self.has_passkeys(**options, &block)
            include Unmagic::Passkeys::Holder
            has_passkeys(**options, &block)
          end
        end
      end

      initializer "unmagic_passkeys.form_helper" do
        ActiveSupport.on_load(:action_view) do
          require "unmagic/passkeys/form_helper"
          include Unmagic::Passkeys::FormHelper
        end
      end

      initializer "unmagic_passkeys.request" do
        ActiveSupport.on_load(:action_controller) do
          require "unmagic/passkeys/request"
        end
      end

      initializer "unmagic_passkeys.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << root.join("app/assets/javascripts").to_s
        end
      end

      initializer "unmagic_passkeys.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << root.join("app/assets/javascripts")
        end
      end
    end
  end
end
