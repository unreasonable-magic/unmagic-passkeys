# frozen_string_literal: true

require_relative "lib/unmagic/passkeys/version"

Gem::Specification.new do |spec|
  spec.name        = "unmagic-passkeys"
  spec.version     = Unmagic::Passkeys::VERSION
  spec.authors     = [ "Keith Pitt" ]
  spec.email       = [ "keith@unreasonable-magic.com" ]
  spec.summary     = "Passkey (WebAuthn) authentication for Rails, with no external dependencies"
  spec.description = "A Rails engine that adds passkey registration and authentication backed by " \
    "Active Record. Self-contained, pure-Ruby WebAuthn ceremonies (CBOR, COSE, attestation and " \
    "assertion verification) with stateless signed challenges — no external gems."
  spec.homepage    = "https://github.com/unreasonable-magic/unmagic-passkeys"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "README.md", "LICENSE", "NOTICE", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "actionpack", ">= 7.1"
  spec.add_dependency "actionview", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "railties", ">= 7.1"
end
