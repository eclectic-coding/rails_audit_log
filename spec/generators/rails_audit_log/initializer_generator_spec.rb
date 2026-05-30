require "rails_helper"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "generators/rails_audit_log/initializer/initializer_generator"

RSpec.describe RailsAuditLog::Generators::InitializerGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests RailsAuditLog::Generators::InitializerGenerator
  destination File.expand_path("../../../tmp/generator", __dir__)

  before { prepare_destination }

  describe "initializer" do
    before { run_generator }

    let(:initializer_path) { "#{destination_root}/config/initializers/rails_audit_log.rb" }
    let(:content) { File.read(initializer_path) }

    it "creates the initializer file" do
      expect(File.exist?(initializer_path)).to be true
    end

    it "wraps settings in a configure block" do
      expect(content).to include("RailsAuditLog.configure do |config|")
    end

    it "includes all configuration options as commented examples" do
      expect(content).to include("ignored_attributes")
      expect(content).to include("store_snapshot")
      expect(content).to include("capture_request_metadata")
      expect(content).to include("whodunnit_display")
      expect(content).to include("version_limit")
      expect(content).to include("async")
      expect(content).to include("connects_to")
      expect(content).to include("page_size")
    end
  end
end
