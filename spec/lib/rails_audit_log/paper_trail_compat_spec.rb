require "rails_helper"
require "rails_audit_log/paper_trail_compat"

RSpec.describe RailsAuditLog::PaperTrailCompat do
  before do
    Post.include(described_class) unless Post.include?(described_class)
  end

  let!(:post) { Post.create!(title: "Hello") }

  describe ".versions association" do
    it "returns the same records as audit_log_entries" do
      expect(post.versions.map(&:id)).to eq(post.audit_log_entries.order(created_at: :asc, id: :asc).map(&:id))
    end

    it "orders entries oldest-first" do
      post.update!(title: "World")
      ids = post.versions.map(&:id)
      expect(ids).to eq(ids.sort)
    end
  end

  describe "#paper_trail" do
    it "returns a Proxy instance" do
      expect(post.paper_trail).to be_a(RailsAuditLog::PaperTrailCompat::Proxy)
    end

    it "memoises the proxy" do
      expect(post.paper_trail).to be(post.paper_trail)
    end
  end

  describe "Proxy#version" do
    it "returns the most recent audit entry" do
      post.update!(title: "Updated")
      expect(post.paper_trail.version.event).to eq("update")
    end

    it "returns nil when the record has no entries" do
      RailsAuditLog.disable { post.update!(title: "Silent") }
      Post.where(id: post.id).each do |p|
        RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: p.id).delete_all
        expect(p.paper_trail.version).to be_nil
      end
    end
  end

  describe "Proxy#previous_version" do
    it "returns nil for a create entry (nothing existed before)" do
      expect(post.paper_trail.previous_version).to be_nil
    end

    it "returns reconstructed state before the most recent change" do
      original_title = post.title
      post.update!(title: "New Title")
      prev = post.paper_trail.previous_version
      expect(prev.title).to eq(original_title)
    end
  end

  describe "Proxy#originator" do
    it "returns nil when no actor is set" do
      expect(post.paper_trail.originator).to be_nil
    end

    it "returns the whodunnit_snapshot of the most recent entry" do
      user = User.create!(name: "Alice")
      RailsAuditLog.with_actor(user) { post.update!(title: "By Alice") }
      expect(post.paper_trail.originator).to eq("Alice")
    end
  end

  describe "Proxy#version_at" do
    it "delegates to RailsAuditLog.version_at" do
      post.update!(title: "v2")
      snapshot = post.paper_trail.version_at(Time.current)
      expect(snapshot).not_to be_nil
    end
  end
end
