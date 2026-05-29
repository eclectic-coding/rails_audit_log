require "rails_helper"

RSpec.describe RailsAuditLog::Auditable do
  describe "audit_log_entries association" do
    it "provides a has_many association on the including model" do
      post = Post.create!(title: "Hello")
      expect(post.audit_log_entries).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it "destroys entries when the record is destroyed" do
      post = Post.create!(title: "Hello")
      entry_id = post.audit_log_entries.first.id
      post.destroy!
      expect(RailsAuditLog::AuditLogEntry.where(id: entry_id)).to be_empty
    end
  end

  describe "create tracking" do
    it "records a create entry" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.first
      expect(entry.event).to eq("create")
    end

    it "stores object_changes with [nil, value] pairs" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.first
      expect(entry.object_changes["title"]).to eq([nil, "Hello"])
    end

    it "sets item_type and item_id" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.first
      expect(entry.item_type).to eq("Post")
      expect(entry.item_id).to eq(post.id)
    end
  end

  describe "update tracking" do
    it "records an update entry" do
      post = Post.create!(title: "Hello")
      post.update!(title: "World")
      update_entry = post.audit_log_entries.find_by(event: "update")
      expect(update_entry).not_to be_nil
    end

    it "stores only changed attributes in object_changes" do
      post = Post.create!(title: "Hello")
      post.update!(title: "World")
      update_entry = post.audit_log_entries.find_by(event: "update")
      expect(update_entry.object_changes["title"]).to eq(["Hello", "World"])
      expect(update_entry.object_changes).not_to have_key("body")
    end
  end

  describe "destroy tracking" do
    it "records a destroy entry" do
      post = Post.create!(title: "Hello")
      post.destroy!
      entries = RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id)
      destroy_entry = entries.find_by(event: "destroy")
      expect(destroy_entry).not_to be_nil
    end

    it "stores the final attribute values in object_changes" do
      post = Post.create!(title: "Hello")
      post.destroy!
      entries = RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id)
      destroy_entry = entries.find_by(event: "destroy")
      expect(destroy_entry.object_changes["title"]).to eq(["Hello", nil])
    end
  end

  describe "actor context" do
    it "records no actor when none is set" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.first
      expect(entry.actor_type).to be_nil
      expect(entry.actor_id).to be_nil
    end

    it "records the actor when set via RailsAuditLog.with_actor" do
      user = User.create!(name: "Alice")
      RailsAuditLog.with_actor(user) do
        post = Post.create!(title: "Hello")
        entry = post.audit_log_entries.first
        expect(entry.actor_type).to eq("User")
        expect(entry.actor_id).to eq(user.id)
      end
    end

    it "restores the previous actor after the block" do
      RailsAuditLog.with_actor(nil) do
        expect(RailsAuditLog.actor).to be_nil
      end
    end

    it "clears actor context outside with_actor" do
      user = User.create!(name: "Bob")
      RailsAuditLog.with_actor(user) { }
      expect(RailsAuditLog.actor).to be_nil
    end
  end
end
