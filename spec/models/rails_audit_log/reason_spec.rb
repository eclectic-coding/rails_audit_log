require "rails_helper"

RSpec.describe "audit_log_reason" do
  let!(:post) { Post.create!(title: "Hello") }

  describe "RailsAuditLog.audit_log_reason" do
    it "stores the reason on entries created inside the block" do
      RailsAuditLog.audit_log_reason("Approved by legal") do
        post.update!(title: "Updated")
      end
      entry = post.audit_log_entries.updated_events.first
      expect(entry.reason).to eq("Approved by legal")
    end

    it "clears the reason after the block" do
      RailsAuditLog.audit_log_reason("Temporary") { post.update!(title: "v2") }
      expect(RailsAuditLog.reason).to be_nil
    end

    it "restores the previous reason after a nested block" do
      RailsAuditLog.audit_log_reason("outer") do
        RailsAuditLog.audit_log_reason("inner") do
          post.update!(title: "inner change")
        end
        expect(RailsAuditLog.reason).to eq("outer")
      end
      expect(RailsAuditLog.reason).to be_nil
    end

    it "restores the reason even if the block raises" do
      RailsAuditLog.audit_log_reason("risky") { raise "boom" } rescue nil
      expect(RailsAuditLog.reason).to be_nil
    end

    it "stores nil reason when no audit_log_reason block is active" do
      post.update!(title: "No reason")
      entry = post.audit_log_entries.updated_events.first
      expect(entry.reason).to be_nil
    end
  end
end
