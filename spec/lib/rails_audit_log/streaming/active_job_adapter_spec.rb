require "rails_helper"

RSpec.describe RailsAuditLog::Streaming::ActiveJobAdapter do
  include ActiveJob::TestHelper

  around do |ex|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ex.run
  ensure
    ActiveJob::Base.queue_adapter = original
    clear_enqueued_jobs
  end

  let(:entry) do
    RailsAuditLog::AuditLogEntry.new(
      event: "create", item_type: "Post", item_id: 1
    )
  end

  describe "#publish" do
    it "enqueues PublishEntryJob with the entry attributes" do
      described_class.new.publish(entry)
      expect(enqueued_jobs.size).to eq(1)
      expect(enqueued_jobs.first["job_class"]).to eq("RailsAuditLog::Streaming::PublishEntryJob")
    end

    it "passes the entry attributes as the job argument" do
      described_class.new.publish(entry)
      args = enqueued_jobs.first["arguments"].first
      expect(args["event"]).to eq("create")
      expect(args["item_type"]).to eq("Post")
      expect(args["item_id"]).to eq(1)
    end

    it "uses the default queue when none is specified" do
      described_class.new.publish(entry)
      expect(enqueued_jobs.first["queue_name"]).to eq("default")
    end

    it "enqueues on the specified queue" do
      described_class.new(queue: :streaming).publish(entry)
      expect(enqueued_jobs.first["queue_name"]).to eq("streaming")
    end
  end
end
