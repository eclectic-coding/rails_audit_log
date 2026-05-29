require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "instance methods" do
  let(:post) { Post.create!(title: "Hello") }

  def entry(changes)
    described_class.create!(event: "update", item_type: "Post", item_id: post.id, object_changes: changes)
  end

  describe "#changed_attributes" do
    it "returns the list of attribute keys that changed" do
      e = entry("title" => ["Hello", "World"], "body" => [nil, "Content"])
      expect(e.changed_attributes).to contain_exactly("title", "body")
    end

    it "returns an empty array when object_changes is nil" do
      e = described_class.create!(event: "create", item_type: "Post", item_id: post.id, object_changes: nil)
      expect(e.changed_attributes).to eq([])
    end
  end

  describe "#diff" do
    it "returns a hash of attribute => { from:, to: } pairs" do
      e = entry("title" => ["Hello", "World"])
      expect(e.diff).to eq("title" => { from: "Hello", to: "World" })
    end

    it "handles multiple changed attributes" do
      e = entry("title" => ["Hello", "World"], "body" => [nil, "Content"])
      expect(e.diff).to eq(
        "title" => { from: "Hello", to: "World" },
        "body"  => { from: nil,     to: "Content" }
      )
    end

    it "returns an empty hash when object_changes is nil" do
      e = described_class.create!(event: "create", item_type: "Post", item_id: post.id, object_changes: nil)
      expect(e.diff).to eq({})
    end
  end

  describe "#actor" do
    it "returns the associated actor record" do
      user = User.create!(name: "Alice")
      e = described_class.create!(
        event: "create", item_type: "Post", item_id: post.id,
        actor_type: "User", actor_id: user.id
      )
      expect(e.actor).to eq(user)
    end

    it "returns nil when no actor is set" do
      e = described_class.create!(event: "create", item_type: "Post", item_id: post.id)
      expect(e.actor).to be_nil
    end
  end
end
