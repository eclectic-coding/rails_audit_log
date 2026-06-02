require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "query scopes" do
  let(:post)  { Post.create!(title: "Hello") }
  let(:user)  { User.create!(name: "Alice") }

  def entry(attrs = {})
    described_class.create!({ event: "create", item_type: "Post", item_id: post.id }.merge(attrs))
  end

  describe "event scopes" do
    before do
      entry(event: "create")
      entry(event: "update")
      entry(event: "destroy")
    end

    it ".created_events returns only create entries" do
      expect(described_class.created_events.pluck(:event)).to all eq("create")
    end

    it ".updated_events returns only update entries" do
      expect(described_class.updated_events.pluck(:event)).to all eq("update")
    end

    it ".destroyed_events returns only destroy entries" do
      expect(described_class.destroyed_events.pluck(:event)).to all eq("destroy")
    end
  end

  describe ".by_actor" do
    it "returns entries for the given actor" do
      entry(actor_type: "User", actor_id: user.id)
      entry(actor_type: nil,    actor_id: nil)

      results = described_class.by_actor(user)
      expect(results.count).to eq(1)
      expect(results.first.actor_id).to eq(user.id)
    end
  end

  describe ".for_resource" do
    it "returns entries for a specific record" do
      other = Post.create!(title: "Other")
      entry(item_type: "Post", item_id: post.id)
      entry(item_type: "Post", item_id: other.id)

      expect(described_class.for_resource(post).pluck(:item_id)).to all eq(post.id)
    end

    it "returns all entries for a class" do
      entry(item_type: "Post", item_id: post.id)
      entry(item_type: "User", item_id: user.id)

      expect(described_class.for_resource(Post).pluck(:item_type)).to all eq("Post")
    end
  end

  describe ".since and .until" do
    it ".since returns entries at or after the given time" do
      old = entry
      old.update_columns(created_at: 2.days.ago)
      recent = entry

      results = described_class.since(1.day.ago)
      expect(results).to include(recent)
      expect(results).not_to include(old)
    end

    it ".until returns entries at or before the given time" do
      old = entry
      old.update_columns(created_at: 2.days.ago)
      entry

      results = described_class.until(1.day.ago)
      expect(results).to include(old)
    end
  end

  describe ".slim" do
    before { post; described_class.delete_all }

    it "excludes object_changes, object, and metadata from selected attributes" do
      entry(object_changes: { "title" => ["old", "new"] }, metadata: { "ip" => "1.2.3.4" })

      result = described_class.slim.first
      expect(result.has_attribute?(:object_changes)).to be false
      expect(result.has_attribute?(:object)).to be false
      expect(result.has_attribute?(:metadata)).to be false
    end

    it "still loads non-blob columns" do
      entry(event: "update", actor_type: "User", actor_id: 1, reason: "test")

      result = described_class.slim.first
      expect(result.event).to eq("update")
      expect(result.item_type).to eq("Post")
      expect(result.actor_type).to eq("User")
      expect(result.reason).to eq("test")
    end

    it "is chainable with other scopes" do
      entry(event: "create")
      entry(event: "update")

      # Use .length (loads records) instead of .count — chaining select+count
      # requires count(:id) due to SQLite/AR limitations with multi-column SELECT.
      results = described_class.slim.updated_events
      expect(results.length).to eq(1)
      expect(results.first.event).to eq("update")
      expect(results.first.has_attribute?(:object_changes)).to be false
    end

    it "loads all columns without .slim" do
      entry(object_changes: { "title" => ["a", "b"] })

      result = described_class.first
      expect(result.has_attribute?(:object_changes)).to be true
      expect(result.object_changes).to eq("title" => ["a", "b"])
    end
  end

  describe ".touching" do
    before { post; described_class.delete_all }

    it "returns entries where object_changes includes the given attribute" do
      entry(object_changes: { "title" => ["Hello", "World"] })
      entry(object_changes: { "body"  => [nil, "Content"] })

      results = described_class.touching(:title)
      expect(results.count).to eq(1)
      expect(results.first.object_changes["title"]).to eq(["Hello", "World"])
    end

    it "returns no entries when no changes include the attribute" do
      entry(object_changes: { "body" => [nil, "Content"] })
      expect(described_class.touching(:title)).to be_empty
    end
  end

  describe ".for_tenant" do
    before { post; described_class.delete_all }

    it "returns only entries for the given tenant" do
      entry(tenant_id: "acme")
      entry(tenant_id: "globex")
      entry(tenant_id: nil)

      results = described_class.for_tenant("acme")
      expect(results.count).to eq(1)
      expect(results.first.tenant_id).to eq("acme")
    end

    it "returns an empty relation when no entries match" do
      entry(tenant_id: "globex")
      expect(described_class.for_tenant("acme")).to be_empty
    end

    it "is composable with other scopes" do
      entry(event: "create", tenant_id: "acme")
      entry(event: "update", tenant_id: "acme")
      entry(event: "create", tenant_id: "globex")

      results = described_class.for_tenant("acme").created_events
      expect(results.count).to eq(1)
      expect(results.first.event).to eq("create")
    end
  end
end
