require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "#reify" do
  let!(:post) { Post.create!(title: "Original", body: "Hello") }

  describe "create events" do
    it "returns nil — nothing existed before the record was created" do
      entry = post.audit_log_entries.created_events.first
      expect(entry.reify).to be_nil
    end
  end

  describe "update events" do
    before { post.update!(title: "Updated") }

    let(:entry) { post.audit_log_entries.updated_events.first }

    it "returns an unsaved Post instance" do
      expect(entry.reify).to be_a(Post)
      expect(entry.reify).not_to be_persisted
    end

    it "restores the pre-update value of the changed attribute" do
      expect(entry.reify.title).to eq("Original")
    end

    it "preserves unchanged attributes from the current record" do
      expect(entry.reify.body).to eq("Hello")
    end

    it "sets id to the original record id" do
      expect(entry.reify.id).to eq(post.id)
    end
  end

  describe "destroy events" do
    before { post.destroy }

    let(:entry) { RailsAuditLog::AuditLogEntry.destroyed_events.last }

    it "returns an unsaved Post instance" do
      expect(entry.reify).to be_a(Post)
      expect(entry.reify).not_to be_persisted
    end

    it "restores all attribute values from before the destroy" do
      result = entry.reify
      expect(result.title).to eq("Original")
      expect(result.body).to eq("Hello")
    end

    it "sets id to the original record id" do
      expect(entry.reify.id).to eq(post.id)
    end
  end

  describe "edge cases" do
    it "handles a nil object_changes gracefully for update events" do
      entry = described_class.create!(
        event: "update", item_type: "Post", item_id: post.id, object_changes: nil
      )
      result = entry.reify
      expect(result).to be_a(Post)
      expect(result.id).to eq(post.id)
    end

    it "raises NameError for an unresolvable item_type" do
      entry = described_class.new(event: "destroy", item_type: "Nonexistent", item_id: 1,
                                  object_changes: { "id" => [1, nil] })
      expect { entry.reify }.to raise_error(NameError)
    end
  end
end
