require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "selective tracking" do
  # Inline models configured with filtering options
  let(:only_model) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "OnlyPost"
      include RailsAuditLog::Auditable
      audit_log only: [:title]
    end
  end

  let(:ignore_model) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "IgnorePost"
      include RailsAuditLog::Auditable
      audit_log ignore: [:body]
    end
  end

  describe "only: option" do
    it "records only the listed attributes" do
      record = only_model.create!(title: "Hello", body: "Content")
      entry  = RailsAuditLog::AuditLogEntry.where(item_type: record.class.name, item_id: record.id).last
      expect(entry.object_changes.keys).to eq(["title"])
    end

    it "skips updates that touch no tracked attributes" do
      record = only_model.create!(title: "Hello")
      count_before = RailsAuditLog::AuditLogEntry.count
      record.update!(body: "Changed body only")
      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end
  end

  describe "ignore: option" do
    it "excludes the listed attributes from changes" do
      record = ignore_model.create!(title: "Hello", body: "Content")
      entry  = RailsAuditLog::AuditLogEntry.where(item_type: record.class.name, item_id: record.id).last
      expect(entry.object_changes.keys).not_to include("body")
      expect(entry.object_changes.keys).to include("title")
    end
  end

  describe "default ignored attributes" do
    it "excludes updated_at from changes by default" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.last
      expect(entry.object_changes.keys).not_to include("updated_at")
    end

    it "respects a custom global ignored_attributes setting" do
      original = RailsAuditLog.ignored_attributes
      RailsAuditLog.ignored_attributes = %w[updated_at body]

      post = Post.create!(title: "Hello", body: "Content")
      entry = post.audit_log_entries.last
      expect(entry.object_changes.keys).not_to include("body")
    ensure
      RailsAuditLog.ignored_attributes = original
    end
  end
end
