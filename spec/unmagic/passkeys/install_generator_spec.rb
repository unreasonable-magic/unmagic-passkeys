# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/active_record"
require "tmpdir"

RSpec.describe "unmagic:passkeys:install generator" do
  let(:generator_path) do
    File.expand_path("../../../lib/generators/unmagic/passkeys/install_generator.rb", __dir__)
  end

  it "loads even when a Rails constant is nested inside the gem namespace" do
    # 0.2.0 regression: Unmagic::Passkeys::Rails (then home of the routes
    # macro) shadowed ::Rails during the generator's class-body constant
    # lookup, so `rails generate unmagic:passkeys:install` crashed on load.
    stub_const("Unmagic::Passkeys::Rails", Module.new)

    load generator_path

    expect(Unmagic::Passkeys::Generators::InstallGenerator.ancestors).to include(::Rails::Generators::Base)
  end

  it "copies the credentials migration and imports the JavaScript" do
    load generator_path

    Dir.mktmpdir do |destination|
      FileUtils.mkdir_p(File.join(destination, "app/javascript"))
      File.write(File.join(destination, "app/javascript/application.js"), "import \"controllers\"\n")

      shell = Thor::Shell::Basic.new
      shell.mute do
        Unmagic::Passkeys::Generators::InstallGenerator.start([], destination_root: destination, shell: shell)
      end

      migration = Dir[File.join(destination, "db/migrate/*_create_unmagic_passkeys_credentials.rb")].sole
      expect(File.read(migration)).to include("create_table :unmagic_passkeys_credentials")

      application_js = File.read(File.join(destination, "app/javascript/application.js"))
      expect(application_js).to end_with(%(import "unmagic/passkeys"\n))
    end
  end
end
