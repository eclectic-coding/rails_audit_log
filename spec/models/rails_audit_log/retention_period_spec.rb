require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "retention_period" do
  around do |ex|
    RailsAuditLog.retention_period = nil
    ex.run
  ensure
    RailsAuditLog.retention_period = nil
  end

  describe "global retention_period" do
    it "prunes entries older than the period after each write" do
      record = Post.create!(title: "v1")
      old_entry = record.audit_log_entries.first
      old_entry.update_columns(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      record.update!(title: "v2")

      expect(record.audit_log_entries.exists?(old_entry.id)).to be false
    end

    it "retains entries within the period" do
      record = Post.create!(title: "v1")
      RailsAuditLog.retention_period = 90.days
      record.update!(title: "v2")

      expect(record.audit_log_entries.count).to eq(2)
    end

    it "scopes pruning to the specific record" do
      r1 = Post.create!(title: "r1")
      r2 = Post.create!(title: "r2")
      r1.audit_log_entries.update_all(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      r1.update!(title: "r1-new")

      expect(r1.audit_log_entries.count).to eq(1) # only the new update entry
      expect(r2.audit_log_entries.count).to eq(1) # untouched
    end

    it "does nothing when retention_period is nil" do
      record = Post.create!(title: "v1")
      record.audit_log_entries.update_all(created_at: 365.days.ago)
      record.update!(title: "v2")

      expect(record.audit_log_entries.count).to eq(2)
    end
  end

  describe "composing retention_period with version_limit" do
    it "applies both constraints independently" do
      record = Post.create!(title: "v1")
      record.update!(title: "v2")
      record.update!(title: "v3")

      # Age the first two entries past the retention window
      record.audit_log_entries.order(:id).limit(2).update_all(created_at: 91.days.ago)

      RailsAuditLog.retention_period = 90.days
      RailsAuditLog.version_limit    = 5

      record.update!(title: "v4")

      # Aged entries pruned by retention_period; remaining <= version_limit
      entries = record.audit_log_entries.order(:id)
      expect(entries.count).to eq(2)
      expect(entries.map { |e| e.object_changes["title"].last }).to eq(%w[v3 v4])
    ensure
      RailsAuditLog.version_limit = nil
    end
  end

  describe "async with retention_period" do
    around do |ex|
      RailsAuditLog.retention_period = 90.days
      ex.run
    ensure
      RailsAuditLog.retention_period = nil
    end

    it "passes retention_period to WriteAuditLogJob" do
      expect(RailsAuditLog::WriteAuditLogJob).to receive(:perform_later)
        .with(anything, hash_including(retention_period: 90.days))
      Post.new(title: "x").tap do |p|
        p.singleton_class.include(RailsAuditLog::Auditable)
        p.singleton_class.send(:define_method, :_audit_log_async) { true }
        p.save!
      end
    end

    it "prunes expired entries when the job runs" do
      record = Post.create!(title: "v1")
      old_entry = record.audit_log_entries.first
      old_entry.update_columns(created_at: 91.days.ago)

      RailsAuditLog::WriteAuditLogJob.perform_now(
        { "event" => "update", "item_type" => "Post", "item_id" => record.id,
          "object_changes" => { "title" => %w[v1 v2] } },
        retention_period: 90.days
      )

      expect(record.audit_log_entries.exists?(old_entry.id)).to be false
    end
  end
end
