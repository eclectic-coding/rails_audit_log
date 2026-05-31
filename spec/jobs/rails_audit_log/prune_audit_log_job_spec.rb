require "rails_helper"

RSpec.describe RailsAuditLog::PruneAuditLogJob, type: :job do
  around do |ex|
    RailsAuditLog.retention_period = nil
    RailsAuditLog.version_limit    = nil
    ex.run
  ensure
    RailsAuditLog.retention_period = nil
    RailsAuditLog.version_limit    = nil
  end

  describe "global retention_period" do
    it "prunes entries older than the period across all item_types" do
      post    = Post.create!(title: "old")
      article = Article.create!(title: "old article")
      post.audit_log_entries.update_all(created_at: 91.days.ago)
      article.audit_log_entries.update_all(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      described_class.perform_now

      expect(post.audit_log_entries.count).to eq(0)
      expect(article.audit_log_entries.count).to eq(0)
    end

    it "retains entries within the period" do
      post = Post.create!(title: "recent")
      RailsAuditLog.retention_period = 90.days
      described_class.perform_now

      expect(post.audit_log_entries.count).to eq(1)
    end

    it "does not prune when retention_period is nil" do
      post = Post.create!(title: "v1")
      post.audit_log_entries.update_all(created_at: 365.days.ago)
      described_class.perform_now

      expect(post.audit_log_entries.count).to eq(1)
    end
  end

  describe "global version_limit" do
    it "prunes oldest entries per record across all item_types" do
      post = Post.create!(title: "v1")
      3.times { |i| post.update!(title: "v#{i + 2}") }

      RailsAuditLog.version_limit = 2
      described_class.perform_now

      expect(post.audit_log_entries.count).to eq(2)
    end

    it "scopes pruning per item_id so records do not affect each other" do
      r1 = Post.create!(title: "r1")
      r2 = Post.create!(title: "r2")
      3.times { |i| r1.update!(title: "r1-v#{i}") }

      RailsAuditLog.version_limit = 2
      described_class.perform_now

      expect(r1.audit_log_entries.count).to eq(2)
      expect(r2.audit_log_entries.count).to eq(1)
    end
  end

  describe "per-model retain_for" do
    let(:model) do
      stub_const("PruneRetainPost", Class.new(ApplicationRecord) do
        self.table_name = "posts"
        include RailsAuditLog::Auditable
        audit_log retain_for: 30.days
      end)
    end

    it "uses the per-model period instead of the global" do
      record = model.create!(title: "v1")
      # 60 days old: outside per-model window (30d) but inside a hypothetical 90d global
      record.audit_log_entries.update_all(created_at: 60.days.ago)

      RailsAuditLog.retention_period = 90.days
      described_class.perform_now

      expect(record.audit_log_entries.count).to eq(0)
    end
  end

  describe "composing retention_period and version_limit" do
    it "applies both constraints" do
      post = Post.create!(title: "v1")
      3.times { |i| post.update!(title: "v#{i + 2}") }
      post.audit_log_entries.order(:id).limit(2).update_all(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      RailsAuditLog.version_limit    = 5
      described_class.perform_now

      # 2 expired entries pruned by TTL; remaining 2 are within version_limit
      expect(post.audit_log_entries.count).to eq(2)
    end
  end

  describe "unknown item_type" do
    it "falls back to global settings when the class cannot be constantized" do
      RailsAuditLog.disable do
        RailsAuditLog::AuditLogEntry.create!(
          event: "create", item_type: "Ghost::Model", item_id: 1,
          object_changes: {}
        )
      end
      RailsAuditLog::AuditLogEntry
        .where(item_type: "Ghost::Model")
        .update_all(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      expect { described_class.perform_now }.not_to raise_error
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Ghost::Model").count).to eq(0)
    end
  end

  describe "no retention policy configured" do
    it "does nothing and leaves all entries intact" do
      post = Post.create!(title: "keep me")
      described_class.perform_now
      expect(post.audit_log_entries.count).to eq(1)
    end
  end
end
