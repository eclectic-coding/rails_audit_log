require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "join-table tracking" do
  # has_many :through — only :tags tracked (not the intermediate :taggings)
  let(:post_through) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "PostThrough"
      include RailsAuditLog::Auditable
      audit_log associations: [:tags]
      has_many :taggings, foreign_key: :post_id, class_name: "Tagging"
      has_many :tags, through: :taggings
    end
  end

  describe "has_many :through" do
    it "records an update entry when a tag is added via <<" do
      post = post_through.create!(title: "Through Post")
      tag  = Tag.create!(name: "Ruby")
      post.tags << tag

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "PostThrough", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["tags"]).to eq([nil, { "id" => tag.id, "type" => "Tag" }])
    end

    it "records an update entry when a tag is removed" do
      post = post_through.create!(title: "Through Post")
      tag  = Tag.create!(name: "Ruby")
      post.tags << tag
      post.tags.delete(tag)

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "PostThrough", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["tags"]).to eq([{ "id" => tag.id, "type" => "Tag" }, nil])
    end

    it "respects RailsAuditLog.disable" do
      post  = post_through.create!(title: "Through Post")
      tag   = Tag.create!(name: "Ruby")
      count = RailsAuditLog::AuditLogEntry.count

      RailsAuditLog.disable { post.tags << tag }

      expect(RailsAuditLog::AuditLogEntry.count).to eq(count)
    end
  end

  # HABTM tests use the concrete Post model since Rails' internal HABTM proxy
  # class cannot be resolved when has_and_belongs_to_many is declared on an
  # anonymous Class.new(...) — Post already has audit_log associations: true
  # and has_and_belongs_to_many :tags, join_table: :post_tags.
  describe "has_and_belongs_to_many" do
    it "records an update entry when a tag is added via <<" do
      post = Post.create!(title: "HABTM Post")
      tag  = Tag.create!(name: "Rails")
      post.tags << tag

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "Post", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["tags"]).to eq([nil, { "id" => tag.id, "type" => "Tag" }])
    end

    it "records an update entry when a tag is removed" do
      post = Post.create!(title: "HABTM Post")
      tag  = Tag.create!(name: "Rails")
      post.tags << tag
      post.tags.delete(tag)

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "Post", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["tags"]).to eq([{ "id" => tag.id, "type" => "Tag" }, nil])
    end

    it "captures the actor from thread-local context" do
      user = User.create!(name: "Alice")
      post = Post.create!(title: "HABTM Post")
      tag  = Tag.create!(name: "Rails")

      RailsAuditLog.with_actor(user) { post.tags << tag }

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "Post", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry.actor_type).to eq("User")
      expect(entry.actor_id).to eq(user.id)
    end

    it "respects RailsAuditLog.disable" do
      post  = Post.create!(title: "HABTM Post")
      tag   = Tag.create!(name: "Rails")
      count = RailsAuditLog::AuditLogEntry.count

      RailsAuditLog.disable { post.tags << tag }

      expect(RailsAuditLog::AuditLogEntry.count).to eq(count)
    end
  end
end
