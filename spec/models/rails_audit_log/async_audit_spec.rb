require "rails_helper"

RSpec.describe RailsAuditLog::Auditable, "async" do
  include ActiveJob::TestHelper

  let(:async_model) do
    Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "AsyncPost"
      include RailsAuditLog::Auditable
      audit_log async: true
    end
  end

  around do |ex|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ex.run
  ensure
    ActiveJob::Base.queue_adapter = original
    clear_enqueued_jobs
  end

  describe "per-model async: true" do
    it "enqueues WriteAuditLogJob on create instead of writing inline" do
      expect {
        async_model.create!(title: "hello")
      }.to have_enqueued_job(RailsAuditLog::WriteAuditLogJob)
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "AsyncPost").count).to eq(0)
    end

    it "enqueues WriteAuditLogJob on update" do
      record = perform_enqueued_jobs { async_model.create!(title: "hello") }
      expect {
        record.update!(title: "world")
      }.to have_enqueued_job(RailsAuditLog::WriteAuditLogJob)
    end

    it "enqueues WriteAuditLogJob on destroy" do
      record = perform_enqueued_jobs { async_model.create!(title: "hello") }
      expect {
        record.destroy
      }.to have_enqueued_job(RailsAuditLog::WriteAuditLogJob)
    end

    it "creates the entry when the job is performed" do
      perform_enqueued_jobs do
        async_model.create!(title: "hello")
      end
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "AsyncPost").count).to eq(1)
    end

    it "passes object_changes correctly through the job" do
      record = perform_enqueued_jobs { async_model.create!(title: "hello") }
      perform_enqueued_jobs { record.update!(title: "world") }

      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "AsyncPost", item_id: record.id, event: "update")
        .last
      expect(entry.object_changes["title"]).to eq(["hello", "world"])
    end

    it "does not enqueue a job for a model without async: true" do
      expect {
        Post.create!(title: "sync write")
      }.not_to have_enqueued_job(RailsAuditLog::WriteAuditLogJob)
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(1)
    end
  end

  describe "global async" do
    around do |ex|
      RailsAuditLog.async = true
      ex.run
    ensure
      RailsAuditLog.async = false
    end

    it "enqueues WriteAuditLogJob for any model when global async is enabled" do
      expect {
        Post.create!(title: "hello")
      }.to have_enqueued_job(RailsAuditLog::WriteAuditLogJob)
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(0)
    end

    it "creates the entry when the job runs" do
      perform_enqueued_jobs { Post.create!(title: "hello") }
      expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post").count).to eq(1)
    end
  end

  describe "async with version_limit" do
    it "passes version_limit to the job and prunes on perform" do
      limited_model = Class.new(ApplicationRecord) do
        self.table_name = "posts"
        def self.name = "AsyncLimitedPost"
        include RailsAuditLog::Auditable
        audit_log async: true, version_limit: 2
      end

      perform_enqueued_jobs { limited_model.create!(title: "v1") }
      perform_enqueued_jobs { limited_model.first.update!(title: "v2") }
      perform_enqueued_jobs { limited_model.first.update!(title: "v3") }

      expect(RailsAuditLog::AuditLogEntry.where(item_type: "AsyncLimitedPost").count).to eq(2)
    end
  end
end
