# frozen_string_literal: true

module Unmagic
  module Passkeys
    module Rails
      # Adds +use_unmagic_passkeys+ to the router. Draws the multi-user passkey
      # auth flows pointing at the engine's base controllers (which your app may
      # subclass and re-point):
      #
      #   resource  :session,  only: [:new, :create, :destroy]   # sign-in page + ceremony + sign-out
      #   resources :passkeys, only: [:index, :create, :destroy] # management, mounted at /my/passkeys
      #
      # Sign-in is usernameless (discoverable credentials), so it works for any
      # number of users out of the box. Account creation (signup) is the app's
      # job — see the README.
      #
      # == Usage
      #
      #   # config/routes.rb
      #   use_unmagic_passkeys
      #
      #   # Customize: re-point a flow at your own controller, skip flows, or
      #   # nest everything under a path scope.
      #   use_unmagic_passkeys scope: "accounts" do
      #     controllers sessions: "sessions", credentials: "my/passkeys"
      #     skip_controllers :credentials
      #   end
      module Routes
        DEFAULT_CONTROLLERS = {
          sessions: "unmagic/passkeys/sessions",
          credentials: "unmagic/passkeys/credentials"
        }.freeze

        # Collects customization from the +use_unmagic_passkeys+ block.
        class Mapping
          attr_reader :credentials_path, :credentials_as

          def initialize
            @controller_overrides = {}
            @skipped = []
            @credentials_path = "my/passkeys"
            @credentials_as = "my_passkeys"
          end

          # Re-point one or more flows at your own controllers (which should
          # inherit from the matching engine base controller):
          #
          #   controllers sessions: "sessions", credentials: "my/passkeys"
          def controllers(map = nil)
            return resolved_controllers if map.nil?

            map.each { |flow, controller| @controller_overrides[flow.to_sym] = controller.to_s }
          end

          # Skip drawing one or more flows: +skip_controllers :credentials+.
          def skip_controllers(*names)
            @skipped.concat(names.map(&:to_sym))
          end

          # Where the management resource is mounted and how its route helpers
          # are named (defaults to +/my/passkeys+ and +my_passkeys_path+).
          def credentials_at(path:, as:)
            @credentials_path = path
            @credentials_as = as
          end

          def draw?(flow)
            !@skipped.include?(flow)
          end

          def controller_for(flow)
            resolved_controllers.fetch(flow)
          end

          private
            def resolved_controllers
              DEFAULT_CONTROLLERS.merge(@controller_overrides)
            end
        end

        # Mixed into ActionDispatch::Routing::Mapper.
        module Mapper
          def use_unmagic_passkeys(scope: nil, &block)
            mapping = Mapping.new
            mapping.instance_exec(&block) if block

            draw = lambda do
              if mapping.draw?(:sessions)
                resource :session, only: %i[new create destroy], controller: mapping.controller_for(:sessions)
              end

              if mapping.draw?(:credentials)
                resources :passkeys, only: %i[index create destroy],
                  controller: mapping.controller_for(:credentials),
                  path: mapping.credentials_path,
                  as: mapping.credentials_as
              end
            end

            scope ? self.scope(scope, &draw) : instance_exec(&draw)
          end
        end
      end
    end
  end
end
