require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "retain_for" do
  let(:model) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "RetainForPost"
      include RailsAuditLog::Auditable
      audit_log retain_for: 30.days
    end
  end

  describe "per-model retain_for" do
    it "prunes entries older than the per-model period after each write" do
      record = model.create!(title: "v1")
      old_entry = record.audit_log_entries.first
      old_entry.update_columns(created_at: 31.days.ago)

      record.update!(title: "v2")

      expect(record.audit_log_entries.exists?(old_entry.id)).to be false
    end

    it "retains entries within the per-model period" do
      record = model.create!(title: "v1")
      record.update!(title: "v2")

      expect(record.audit_log_entries.count).to eq(2)
    end

    it "scopes pruning to the specific record" do
      r1 = model.create!(title: "r1")
      r2 = model.create!(title: "r2")
      r1.audit_log_entries.update_all(created_at: 31.days.ago)

      r1.update!(title: "r1-new")

      expect(r1.audit_log_entries.count).to eq(1)
      expect(r2.audit_log_entries.count).to eq(1)
    end
  end

  describe "per-model retain_for overrides global retention_period" do
    around do |ex|
      RailsAuditLog.retention_period = 90.days
      ex.run
    ensure
      RailsAuditLog.retention_period = nil
    end

    it "uses the per-model period (30 days) not the global (90 days)" do
      record = model.create!(title: "v1")
      # 60 days old: outside per-model window (30d) but inside global (90d)
      record.audit_log_entries.update_all(created_at: 60.days.ago)

      record.update!(title: "v2")

      expect(record.audit_log_entries.count).to eq(1) # old entry pruned by 30d limit
    end

    it "does not affect other models that use the global period" do
      record = Post.create!(title: "v1")
      record.audit_log_entries.update_all(created_at: 60.days.ago)

      record.update!(title: "v2")

      # Post uses global 90d — 60-day-old entry should survive
      expect(record.audit_log_entries.count).to eq(2)
    end
  end

  describe "composing retain_for with version_limit" do
    let(:composed_model) do
      Class.new(ApplicationRecord) do
        self.table_name = "posts"
        def self.name = "ComposedPost"
        include RailsAuditLog::Auditable
        audit_log retain_for: 30.days, version_limit: 5
      end
    end

    it "applies both constraints independently" do
      record = composed_model.create!(title: "v1")
      record.update!(title: "v2")
      record.update!(title: "v3")
      record.audit_log_entries.order(:id).limit(2).update_all(created_at: 31.days.ago)

      record.update!(title: "v4")

      entries = record.audit_log_entries.order(:id)
      expect(entries.count).to eq(2)
      expect(entries.map { |e| e.object_changes["title"].last }).to eq(%w[v3 v4])
    end
  end
end
