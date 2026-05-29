require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "association tracking" do
  let(:all_tracked) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "AssocPost"
      include RailsAuditLog::Auditable
      audit_log associations: true
      has_many :comments, foreign_key: :post_id, class_name: "Comment", dependent: :destroy
    end
  end

  let(:selectively_tracked) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "SelectivePost"
      include RailsAuditLog::Auditable
      audit_log associations: [:comments]
      has_many :comments, foreign_key: :post_id, class_name: "Comment", dependent: :destroy
    end
  end

  let(:not_tracked) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "UntrackedPost"
      include RailsAuditLog::Auditable
      has_many :comments, foreign_key: :post_id, class_name: "Comment", dependent: :destroy
    end
  end

  describe "associations: true" do
    it "records an update entry when a child is added via <<" do
      post    = all_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "First!", post_id: post.id)
      post.comments << comment

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AssocPost", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["comments"]).to eq([nil, { "id" => comment.id, "type" => "Comment" }])
    end

    it "records an update entry when a child is created through the association" do
      post    = all_tracked.create!(title: "Hello")
      comment = post.comments.create!(body: "Via create")

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AssocPost", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["comments"]).to eq([nil, { "id" => comment.id, "type" => "Comment" }])
    end

    it "records an update entry when a child is removed" do
      post    = all_tracked.create!(title: "Hello")
      comment = post.comments.create!(body: "To remove")
      post.comments.delete(comment)

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AssocPost", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["comments"]).to eq([{ "id" => comment.id, "type" => "Comment" }, nil])
    end

    it "captures the actor from thread-local context" do
      user    = User.create!(name: "Alice")
      post    = all_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "hi", post_id: post.id)

      RailsAuditLog.with_actor(user) do
        post.comments << comment
      end

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AssocPost", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry.actor_type).to eq("User")
      expect(entry.actor_id).to eq(user.id)
    end

    it "respects RailsAuditLog.disable" do
      post    = all_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "silent", post_id: post.id)
      count_before = RailsAuditLog::AuditLogEntry.count

      RailsAuditLog.disable { post.comments << comment }

      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end

    it "respects skip_audit_log" do
      post    = all_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "silent", post_id: post.id)
      count_before = RailsAuditLog::AuditLogEntry.count

      post.skip_audit_log { post.comments << comment }

      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end
  end

  describe "associations: [:name]" do
    it "tracks associations in the list" do
      post    = selectively_tracked.create!(title: "Hello")
      comment = post.comments.create!(body: "Tracked")

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "SelectivePost", item_id: post.id, event: "update")
        .order(:id).last
      expect(entry).not_to be_nil
      expect(entry.object_changes["comments"]).to eq([nil, { "id" => comment.id, "type" => "Comment" }])
    end
  end

  describe "without associations option" do
    it "does not track association changes" do
      post    = not_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "silent", post_id: post.id)
      count_before = RailsAuditLog::AuditLogEntry.count

      post.comments << comment

      expect(RailsAuditLog::AuditLogEntry.count).to eq(count_before)
    end
  end

  describe "belongs_to (column-based)" do
    it "tracks foreign key changes via the child's own audit trail" do
      post    = all_tracked.create!(title: "Hello")
      comment = Comment.create!(body: "Draft", post_id: post.id)
      other   = all_tracked.create!(title: "Other")

      comment.update!(post_id: other.id)

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AssocPost", item_id: post.id, event: "create")
        .first
      expect(entry).not_to be_nil
    end
  end
end
