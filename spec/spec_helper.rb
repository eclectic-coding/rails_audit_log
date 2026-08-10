require "simplecov"
require "simplecov-json"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
])

SimpleCov.start "rails" do
  skip "/spec/"
  skip "/lib/rails_audit_log/version.rb"
  skip "/lib/generators/"
  skip "/app/controllers/rails_audit_log/application_controller.rb"
  skip "/app/views/"

  group "Models",      "app/models"
  group "Concerns",    "app/concerns"
  group "Controllers", "app/controllers"
  group "Helpers",     "app/helpers"
  group "Jobs",        "app/jobs"
  group "Views",       "app/views"
  group "Library",     "lib"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  require "rails_audit_log/matchers"
  config.include RailsAuditLog::Matchers

  require "rails_audit_log/test_helpers"
  config.include RailsAuditLog::TestHelpers

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
