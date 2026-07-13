# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Unmagic
  module Passkeys
    module Generators
      # Installs unmagic-passkeys into a host app: copies the credentials migration
      # (matching the host's primary-key type), imports the JavaScript, and prints the
      # remaining controller/route/view wiring to do.
      #
      # +Rails+ is referenced with a leading +::+ throughout: inside the
      # Unmagic::Passkeys namespace a nested constant named Rails (0.2.0 had one
      # for the routes macro) shadows the framework and breaks the generator.
      class InstallGenerator < ::Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        source_root File.expand_path("templates", __dir__)

        desc "Copies the unmagic_passkeys_credentials migration and wires the JavaScript."

        def create_migration_file
          migration_template "create_unmagic_passkeys_credentials.rb.tt",
            "db/migrate/create_unmagic_passkeys_credentials.rb"
        end

        def import_javascript
          application_js = "app/javascript/application.js"

          if File.exist?(File.join(destination_root, application_js))
            append_to_file application_js, %(import "unmagic/passkeys"\n)
          end
        end

        def show_post_install
          readme "POST_INSTALL" if behavior == :invoke
        end

        private
          def key_type
            ::Rails.configuration.generators.options.dig(:active_record, :primary_key_type)
          end

          def table_id_option
            ", id: :#{key_type}" if key_type
          end

          def holder_id_type
            key_type || :bigint
          end
      end
    end
  end
end
