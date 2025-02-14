# frozen_string_literal: true

require_relative "lib/app_store_server_api/version"

Gem::Specification.new do |spec|
  spec.name = "app_store_server_api_client"
  spec.version = AppStoreServerApi::VERSION
  spec.authors = ["mingos"]
  spec.email = ["mingos@pumb.jp"]

  spec.summary = "A Ruby client for App Store Server API"
  spec.description = "Manage your customers' App Store transactions from your server."
  spec.homepage = "https://github.com/mingos/app-store-server-api-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = [spec.homepage, "CHANGELOG.md"].join("/")

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "jwt", "~> 2.8"
  spec.add_dependency "faraday", "~> 2.12"
  spec.add_dependency "retriable", "~> 3.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
