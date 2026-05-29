require "rails_helper"

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
