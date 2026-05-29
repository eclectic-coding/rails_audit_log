require "rails_helper"

RSpec.describe "Full object snapshot storage" do
  let!(:post) { Post.create!(title: "Original", body: "Hello") }

  describe "store_snapshot: true (default)" do
    it "stores nil for create events (no pre-create state)" do
      entry = post.audit_log_entries.created_events.first
      expect(entry.object).to be_nil
    end

    it "stores the pre-update attribute snapshot for update events" do
      post.update!(title: "Updated")
      entry = post.audit_log_entries.updated_events.first
      expect(entry.object).to include("title" => "Original", "body" => "Hello")
    end

    it "snapshot includes all attributes, not just changed ones" do
      post.update!(title: "Updated")
      entry = post.audit_log_entries.updated_events.first
      expect(entry.object.keys).to include("id", "title", "body", "created_at", "updated_at")
    end

    it "stores the pre-delete attribute snapshot for destroy events" do
      id = post.id
      post.destroy
      entry = RailsAuditLog::AuditLogEntry.destroyed_events.last
      expect(entry.object).to include("id" => id, "title" => "Original", "body" => "Hello")
    end
  end

  describe "store_snapshot: false (diff-only mode)" do
    around { |ex| RailsAuditLog.store_snapshot = false; ex.run; RailsAuditLog.store_snapshot = true }

    it "stores nil for create events" do
      post2 = Post.create!(title: "New")
      entry = post2.audit_log_entries.created_events.first
      expect(entry.object).to be_nil
    end

    it "stores nil for update events" do
      post.update!(title: "Updated")
      entry = post.audit_log_entries.updated_events.first
      expect(entry.object).to be_nil
    end

    it "stores nil for destroy events" do
      post.destroy
      entry = RailsAuditLog::AuditLogEntry.destroyed_events.last
      expect(entry.object).to be_nil
    end
  end

  describe "reify with snapshot present" do
    it "uses the stored snapshot instead of a DB lookup for update events" do
      post.update!(title: "Updated")
      entry = post.audit_log_entries.updated_events.first

      expect(entry.object).to be_present
      result = entry.reify
      expect(result.title).to eq("Original")
      expect(result.body).to eq("Hello")
      expect(result.id).to eq(post.id)
    end

    it "uses the stored snapshot for destroy events" do
      id = post.id
      post.destroy
      entry = RailsAuditLog::AuditLogEntry.destroyed_events.last

      expect(entry.object).to be_present
      result = entry.reify
      expect(result.title).to eq("Original")
      expect(result.id).to eq(id)
    end
  end
end
