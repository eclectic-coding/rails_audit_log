require "rails_helper"

RSpec.describe "disable/enable tracking" do
  describe "RailsAuditLog.enabled?" do
    it "returns true by default" do
      expect(RailsAuditLog.enabled?).to be true
    end

    it "returns false inside a disable block" do
      RailsAuditLog.disable do
        expect(RailsAuditLog.enabled?).to be false
      end
    end

    it "returns true again after the disable block" do
      RailsAuditLog.disable { }
      expect(RailsAuditLog.enabled?).to be true
    end
  end

  describe "RailsAuditLog.disable" do
    it "suppresses audit entries for all models inside the block" do
      count_before = RailsAuditLog::AuditLogEntry.count
      RailsAuditLog.disable do
        Post.create!(title: "Silent post")
      end
      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end

    it "resumes tracking after the block" do
      RailsAuditLog.disable { Post.create!(title: "Silent") }
      expect { Post.create!(title: "Tracked") }
        .to change { RailsAuditLog::AuditLogEntry.count }.by(1)
    end

    it "restores tracking even if the block raises" do
      begin
        RailsAuditLog.disable { raise "boom" }
      rescue RuntimeError
        nil
      end
      expect(RailsAuditLog.enabled?).to be true
    end
  end

  describe "skip_audit_log" do
    it "suppresses tracking for the duration of the block on a model instance" do
      post = Post.create!(title: "Hello")
      count_before = RailsAuditLog::AuditLogEntry.count
      post.skip_audit_log { post.update!(title: "Silent update") }
      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end

    it "resumes tracking after the block" do
      post = Post.create!(title: "Hello")
      post.skip_audit_log { post.update!(title: "Silent") }
      expect { post.update!(title: "Tracked") }
        .to change { RailsAuditLog::AuditLogEntry.count }.by(1)
    end
  end
end
