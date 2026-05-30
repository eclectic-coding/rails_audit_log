require "simplecov"
require "simplecov-json"

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
])

SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/lib/rails_audit_log/version.rb"
  add_filter "/lib/generators/"
  add_filter "/app/controllers/rails_audit_log/application_controller.rb"
  add_filter "/app/helpers/rails_audit_log/application_helper.rb"

  add_group "Models",      "app/models"
  add_group "Concerns",    "app/concerns"
  add_group "Controllers", "app/controllers"
  add_group "Helpers",     "app/helpers"
  add_group "Jobs",        "app/jobs"
  add_group "Views",       "app/views"
  add_group "Library",     "lib"
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
