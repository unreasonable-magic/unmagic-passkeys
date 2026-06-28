# frozen_string_literal: true

module Unmagic
  module Passkeys
    # Central configuration for the passkeys engine, set through a single
    # +Unmagic::Passkeys.configure+ block. The defaults here are the single
    # source of truth — there is no separate Rails engine config.
    #
    #   # config/initializers/passkeys.rb
    #   Unmagic::Passkeys.configure do |config|
    #     config.relying_party_name           = "Shopping"
    #     config.request_challenge_expiration  = 5.minutes
    #     config.default_request_options       = { user_verification: :required }
    #   end
    class Configuration
      # The Active Record base class the Credential model inherits from.
      attr_accessor :parent_class_name

      # Where the stateless challenge endpoint is mounted, and whether the engine
      # draws it at all. Override these in +config/application.rb+ if you need
      # them applied before the engine draws its routes.
      attr_accessor :routes_prefix, :draw_routes

      # Optional callable, +instance_exec+'d in the view, returning the URL the
      # form helpers point the challenge fetch at. Defaults to the engine's
      # challenge path when nil.
      attr_accessor :challenge_url

      # Global option defaults merged into every registration / authentication
      # ceremony.
      attr_accessor :default_creation_options, :default_request_options

      # How long an issued challenge stays valid, per ceremony.
      attr_accessor :creation_challenge_expiration, :request_challenge_expiration

      # Relying party identity. When nil, falls back to the request host and
      # +Rails.application.name+ respectively.
      attr_accessor :relying_party_id, :relying_party_name

      # The controller the engine's base controllers inherit from. Inherit from
      # the host's +ApplicationController+ so the hook blocks below can call your
      # app's session helpers (e.g. +start_new_session_for+).
      attr_accessor :base_controller

      def initialize
        @parent_class_name = "ApplicationRecord"
        @routes_prefix = "/unmagic/passkeys"
        @draw_routes = true
        @challenge_url = nil
        @default_creation_options = {}
        @default_request_options = {}
        @creation_challenge_expiration = 10.minutes
        @request_challenge_expiration = 5.minutes
        @relying_party_id = nil
        @relying_party_name = nil
        @base_controller = "ApplicationController"
        @sign_in = nil
        @sign_out = nil
        @current_holder = nil
      end

      # == Controller hooks
      #
      # Each is a block +instance_exec+'d in the engine's base controllers, so it
      # has full access to the request, session, and any helpers your
      # +base_controller+ provides. Call with a block to set, without to read.
      #
      # +sign_in+ turns an authenticated holder into an app session (required to
      # use the sign-in flow). +sign_out+ tears it down. +current_holder+ returns
      # the signed-in holder (used by the credentials management controller).
      #
      # Account creation (signup) is the host app's responsibility — once you've
      # created/identified a holder, register a passkey for it with
      # +holder.passkeys.register(params)+ and call +sign_in+.
      #
      #   Unmagic::Passkeys.configure do |config|
      #     config.sign_in        { |holder| start_new_session_for(holder) }
      #     config.sign_out       { terminate_session }
      #     config.current_holder { Current.user }
      #   end
      def sign_in(&block)
        block ? @sign_in = block : @sign_in
      end

      def sign_out(&block)
        block ? @sign_out = block : @sign_out
      end

      def current_holder(&block)
        block ? @current_holder = block : @current_holder
      end
    end
  end
end
