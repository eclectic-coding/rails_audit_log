require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, type: :model do
  let(:post) { Post.create!(title: "Hello") }

  def build_entry(overrides = {})
    described_class.new(
      {
        event:     "create",
        item_type: "Post",
        item_id:   post.id
      }.merge(overrides)
    )
  end

  describe "validations" do
    it "is valid with required attributes" do
      expect(build_entry).to be_valid
    end

    it "requires event" do
      expect(build_entry(event: nil)).not_to be_valid
    end

    it "requires a recognised event value" do
      expect(build_entry(event: "touch")).not_to be_valid
    end

    it "requires item_type" do
      expect(build_entry(item_type: nil)).not_to be_valid
    end

    it "requires item_id" do
      expect(build_entry(item_id: nil)).not_to be_valid
    end

    it "allows a nil actor" do
      entry = build_entry(actor_type: nil, actor_id: nil)
      expect(entry).to be_valid
    end
  end

  describe "EVENTS constant" do
    it "contains create, update, and destroy" do
      expect(described_class::EVENTS).to eq(%w[create update destroy])
    end
  end

  describe "scopes" do
    before do
      described_class.create!(event: "create",  item_type: "Post", item_id: post.id)
      described_class.create!(event: "update",  item_type: "Post", item_id: post.id)
      described_class.create!(event: "destroy", item_type: "Post", item_id: post.id)
    end

    it ".creates returns only create entries" do
      expect(described_class.creates.pluck(:event)).to all eq("create")
    end

    it ".updates returns only update entries" do
      expect(described_class.updates.pluck(:event)).to all eq("update")
    end

    it ".destroys returns only destroy entries" do
      expect(described_class.destroys.pluck(:event)).to all eq("destroy")
    end
  end

  describe "associations" do
    it "belongs_to a polymorphic item" do
      entry = described_class.create!(event: "create", item_type: "Post", item_id: post.id)
      expect(entry.item).to eq(post)
    end

    it "belongs_to an optional polymorphic actor" do
      actor = User.create!(name: "Alice")
      entry = described_class.create!(
        event:      "create",
        item_type:  "Post",
        item_id:    post.id,
        actor_type: "User",
        actor_id:   actor.id
      )
      expect(entry.actor).to eq(actor)
    end
  end

  describe "object_changes" do
    it "stores arbitrary JSON" do
      changes = { "title" => [nil, "Hello"] }
      entry = described_class.create!(
        event:          "create",
        item_type:      "Post",
        item_id:        post.id,
        object_changes: changes
      )
      expect(entry.reload.object_changes).to eq(changes)
    end
  end
end
