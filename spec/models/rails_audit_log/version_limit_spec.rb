require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "version_limit" do
  let(:limited_model) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "LimitedPost"
      include RailsAuditLog::Auditable
      audit_log version_limit: 3
    end
  end

  describe "per-model version_limit" do
    it "does not prune when under the limit" do
      record = limited_model.create!(title: "v1")
      record.update!(title: "v2")
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "LimitedPost", item_id: record.id).count).to eq(2)
    end

    it "prunes oldest entries when the limit is exceeded" do
      record = limited_model.create!(title: "v1")
      record.update!(title: "v2")
      record.update!(title: "v3")
      record.update!(title: "v4")  # 4th entry triggers pruning to 3

      entries = RailsAuditLog::AuditLogEntry
        .where(item_type: "LimitedPost", item_id: record.id)
        .order(:id)
      expect(entries.count).to eq(3)
      expect(entries.first.event).to eq("update")  # create was pruned
      expect(entries.last.object_changes["title"]).to eq(["v3", "v4"])
    end

    it "keeps exactly the limit count after many writes" do
      record = limited_model.create!(title: "start")
      10.times { |i| record.update!(title: "v#{i}") }
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "LimitedPost", item_id: record.id).count).to eq(3)
    end

    it "scopes pruning to the specific record, not all records" do
      r1 = limited_model.create!(title: "r1")
      r2 = limited_model.create!(title: "r2")
      4.times { |i| r1.update!(title: "r1-v#{i}") }

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "LimitedPost", item_id: r1.id).count).to eq(3)
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "LimitedPost", item_id: r2.id).count).to eq(1)
    end
  end

  describe "global version_limit" do
    around do |ex|
      RailsAuditLog.version_limit = 2
      ex.run
    ensure
      RailsAuditLog.version_limit = nil
    end

    it "applies when no per-model limit is set" do
      record = Post.create!(title: "v1")
      record.update!(title: "v2")
      record.update!(title: "v3")  # triggers pruning to 2

      expect(record.audit_log_entries.count).to eq(2)
    end
  end

  describe "per-model overrides global" do
    around do |ex|
      RailsAuditLog.version_limit = 10
      ex.run
    ensure
      RailsAuditLog.version_limit = nil
    end

    it "uses the per-model limit instead of the global one" do
      record = limited_model.create!(title: "v1")
      4.times { |i| record.update!(title: "v#{i}") }

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "LimitedPost", item_id: record.id).count).to eq(3)
    end
  end

  describe "no limit set" do
    it "retains all entries" do
      record = Post.create!(title: "v1")
      5.times { |i| record.update!(title: "v#{i}") }
      expect(record.audit_log_entries.count).to eq(6)
    end
  end
end
