require "rails_helper"

RSpec.describe RailsAuditLog, "batch_audit" do
  describe ".batch_audit" do
    it "inserts all entries in a single insert_all! call" do
      expect(RailsAuditLog::AuditLogEntry).to receive(:insert_all!).once.and_call_original

      RailsAuditLog.batch_audit do
        Post.create!(title: "p1")
        Post.create!(title: "p2")
        Post.create!(title: "p3")
      end

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(3)
    end

    it "writes no entries inline during the block" do
      RailsAuditLog.batch_audit do
        Post.create!(title: "buffered")
        expect(RailsAuditLog::AuditLogEntry.count).to eq(0)
      end
    end

    it "persists all entries after the block completes" do
      RailsAuditLog.batch_audit do
        Post.create!(title: "p1")
        p = Post.create!(title: "p2")
        p.update!(title: "p2-updated")
      end

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(3)
    end

    it "preserves object_changes correctly through insert_all" do
      post = nil
      RailsAuditLog.batch_audit { post = Post.create!(title: "hello") }

      entry = post.audit_log_entries.first
      expect(entry.event).to eq("create")
      expect(entry.object_changes["title"]).to eq([nil, "hello"])
    end

    it "preserves actor context in each entry" do
      user = User.create!(name: "Alice")

      RailsAuditLog.with_actor(user) do
        RailsAuditLog.batch_audit { Post.create!(title: "by alice") }
      end

      entry = RailsAuditLog::AuditLogEntry.where(item_type: "Post").last
      expect(entry.actor_id).to eq(user.id)
      expect(entry.actor_type).to eq("User")
    end

    it "returns the block's return value" do
      result = RailsAuditLog.batch_audit { 42 }
      expect(result).to eq(42)
    end

    it "does not flush entries when the block raises" do
      expect {
        RailsAuditLog.batch_audit do
          Post.create!(title: "before error")
          raise "oops"
        end
      }.to raise_error("oops")

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(0)
    end

    it "restores normal inline writes after the block" do
      RailsAuditLog.batch_audit { Post.create!(title: "batched") }
      RailsAuditLog::AuditLogEntry.delete_all

      Post.create!(title: "inline")
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(1)
    end

    it "does not call insert_all! when no entries are buffered" do
      expect(RailsAuditLog::AuditLogEntry).not_to receive(:insert_all!)

      RailsAuditLog.batch_audit { RailsAuditLog.disable { Post.create!(title: "silent") } }
    end

    it "accumulates nested batch_audit calls into the outer batch with a single insert_all!" do
      expect(RailsAuditLog::AuditLogEntry).to receive(:insert_all!).once.and_call_original

      RailsAuditLog.batch_audit do
        Post.create!(title: "outer")
        RailsAuditLog.batch_audit do
          Post.create!(title: "inner")
        end
      end

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(2)
    end

    it "takes priority over async mode" do
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      begin
        RailsAuditLog.async = true
        RailsAuditLog.batch_audit { Post.create!(title: "no job") }
        expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(0)
        expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(1)
      ensure
        RailsAuditLog.async = false
        ActiveJob::Base.queue_adapter = original
      end
    end
  end
end
