require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "connects_to configuration" do
  after do
    RailsAuditLog.connects_to = nil
  end

  describe "RailsAuditLog.connects_to" do
    it "defaults to nil" do
      expect(RailsAuditLog.connects_to).to be_nil
    end

    it "stores and returns the configured value" do
      opts = { database: { writing: :audit_db, reading: :audit_db } }
      RailsAuditLog.connects_to = opts
      expect(RailsAuditLog.connects_to).to eq(opts)
    end
  end

  describe ".configure_connection!" do
    it "does nothing when connects_to is nil" do
      expect(described_class).not_to receive(:connects_to)
      described_class.configure_connection!
    end

    it "calls connects_to with the configured options when set" do
      opts = { database: { writing: :audit_db, reading: :audit_db } }
      RailsAuditLog.connects_to = opts
      expect(described_class).to receive(:connects_to).with(**opts)
      described_class.configure_connection!
    end

    it "passes keyword options correctly for writing-only config" do
      opts = { database: { writing: :audit_db } }
      RailsAuditLog.connects_to = opts
      expect(described_class).to receive(:connects_to).with(database: { writing: :audit_db })
      described_class.configure_connection!
    end
  end
end
