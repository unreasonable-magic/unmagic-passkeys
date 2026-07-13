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
    #   Unmagic::Passkeys.configure do |config|
    #     config.default_creation_options = { attestation: :none }
    #     config.default_request_options  = { user_verification: :required }
    #     config.routes_prefix            = "/auth/passkeys"
    #   end
    class Engine < ::Rails::Engine
      initializer "unmagic_passkeys.routes" do |app|
        passkey_config = Unmagic::Passkeys.configuration

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
