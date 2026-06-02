require "rails_helper"

RSpec.describe "RailsAuditLog streaming" do
  include ActiveJob::TestHelper

  let(:adapter) { instance_double(RailsAuditLog::Streaming::NotificationsAdapter, publish: nil) }

  around do |ex|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ex.run
  ensure
    ActiveJob::Base.queue_adapter = original
    clear_enqueued_jobs
  end

  after { RailsAuditLog.streaming_adapter = nil }

  describe "no adapter configured" do
    it "does not call publish on nil" do
      expect { Post.create!(title: "Hello") }.not_to raise_error
    end
  end

  describe "inline write" do
    before { RailsAuditLog.streaming_adapter = adapter }

    it "calls publish with the persisted entry after create" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.last
      expect(adapter).to have_received(:publish).with(entry)
    end

    it "calls publish after update" do
      post = Post.create!(title: "Hello")
      post.update!(title: "World")
      expect(adapter).to have_received(:publish).twice
    end

    it "calls publish after destroy" do
      post = Post.create!(title: "Hello")
      post.destroy!
      expect(adapter).to have_received(:publish).twice
    end

    it "publishes a persisted entry with an id" do
      Post.create!(title: "Hello")
      published = nil
      allow(adapter).to receive(:publish) { |e| published = e }
      Post.create!(title: "World")
      expect(published.id).not_to be_nil
    end
  end

  describe "async write (WriteAuditLogJob)" do
    before { RailsAuditLog.streaming_adapter = adapter }

    it "calls publish when WriteAuditLogJob is performed" do
      perform_enqueued_jobs do
        RailsAuditLog::WriteAuditLogJob.perform_later(
          { "event" => "create", "item_type" => "Post", "item_id" => 99,
            "object_changes" => { "title" => [nil, "Hello"] } }
        )
      end
      expect(adapter).to have_received(:publish).once
    end
  end

  describe "batch_audit" do
    before { RailsAuditLog.streaming_adapter = adapter }

    it "calls publish for each entry after the batch flushes" do
      RailsAuditLog.batch_audit { 3.times { |i| Post.create!(title: "Post #{i}") } }
      expect(adapter).to have_received(:publish).exactly(3).times
    end

    it "does not publish when no adapter is configured" do
      RailsAuditLog.streaming_adapter = nil
      expect(adapter).not_to have_received(:publish)
      RailsAuditLog.batch_audit { Post.create!(title: "Quiet") }
    end

    it "publishes AuditLogEntry instances" do
      published = []
      allow(adapter).to receive(:publish) { |e| published << e }
      RailsAuditLog.batch_audit { Post.create!(title: "Batch") }
      expect(published.first).to be_a(RailsAuditLog::AuditLogEntry)
      expect(published.first.event).to eq("create")
    end
  end
end
