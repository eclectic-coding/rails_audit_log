require "rails_helper"

RSpec.describe RailsAuditLog do
  describe ".configure" do
    it "yields the module so settings can be set in a block" do
      RailsAuditLog.configure do |config|
        config.version_limit = 5
      end
      expect(RailsAuditLog.version_limit).to eq(5)
    ensure
      RailsAuditLog.version_limit = nil
    end
  end
end

RSpec.describe RailsAuditLog::Engine do
  it "isolates the RailsAuditLog namespace" do
    expect(described_class.isolated?).to be true
  end

  it "autoloads Auditable without an explicit require" do
    expect(defined?(RailsAuditLog::Auditable)).to eq("constant")
  end

  it "autoloads Controller without an explicit require" do
    expect(defined?(RailsAuditLog::Controller)).to eq("constant")
  end

  it "autoloads AuditLogEntry without an explicit require" do
    expect(defined?(RailsAuditLog::AuditLogEntry)).to eq("constant")
  end
end
