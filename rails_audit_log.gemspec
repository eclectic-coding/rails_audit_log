require_relative "lib/rails_audit_log/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_audit_log"
  spec.version     = RailsAuditLog::VERSION
  spec.authors     = ["Chuck Smith"]
  spec.email       = ["chuck@eclecticcoding.com"]
  spec.homepage    = "https://github.com/eclectic-coding/rails_audit_log"
  spec.summary     = "Zeitwerk-native audit logging for ActiveRecord"
  spec.description = "A modern Rails engine that tracks ActiveRecord create, update, and " \
                     "destroy events with JSON-first storage, whodunnit actor context, and " \
                     "a clean query API. Drop-in replacement for PaperTrail with no legacy baggage."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/eclectic-coding/rails_audit_log"
  spec.metadata["changelog_uri"]   = "https://github.com/eclectic-coding/rails_audit_log/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.2"
  spec.add_dependency "turbo-rails", ">= 2.0"
  spec.add_dependency "importmap-rails", ">= 1.2"
  spec.add_dependency "pagy", ">= 43.0"
end
