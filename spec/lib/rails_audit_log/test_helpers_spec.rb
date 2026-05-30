require "rails_helper"
require "rails_audit_log/test_helpers"

RSpec.describe RailsAuditLog::TestHelpers do
  include RailsAuditLog::TestHelpers

  describe "#without_audit_log" do
    it "suppresses audit entries inside the block" do
      without_audit_log { Post.create!(title: "Silent") }
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(0)
    end

    it "resumes normal tracking after the block" do
      without_audit_log { Post.create!(title: "Silent") }
      Post.create!(title: "Tracked")
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(1)
    end

    it "restores tracking even if the block raises" do
      expect {
        without_audit_log { raise "oops" }
      }.to raise_error("oops")
      expect(RailsAuditLog.enabled?).to be true
    end

    it "returns the block's return value" do
      result = without_audit_log { 42 }
      expect(result).to eq(42)
    end

    it "can be called without a namespace prefix when included" do
      expect { without_audit_log { Post.create!(title: "no prefix") } }.not_to raise_error
    end
  end
end
