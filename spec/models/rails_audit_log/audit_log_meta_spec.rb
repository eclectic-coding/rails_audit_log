require "rails_helper"

RSpec.describe "audit_log meta:" do
  describe "zero-argument lambda (thread-local / global context)" do
    before do
      Post.audit_log meta: { source: -> { "imported" } }
    end

    after { Post._audit_log_meta = nil }

    it "stores the evaluated value in the entry metadata" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.created_events.first
      expect(entry.metadata).to include("source" => "imported")
    end

    it "evaluates the lambda fresh on every write" do
      counter = 0
      Post.audit_log meta: { seq: -> { counter += 1 } }
      post = Post.create!(title: "Hello")
      post.update!(title: "World")
      entries = post.audit_log_entries.order(:id)
      expect(entries[0].metadata["seq"]).to eq(1)
      expect(entries[1].metadata["seq"]).to eq(2)
    end
  end

  describe "one-argument lambda (record context)" do
    before do
      Post.audit_log meta: { title_upcase: ->(record) { record.title.upcase } }
    end

    after { Post._audit_log_meta = nil }

    it "passes the record instance as the argument" do
      post = Post.create!(title: "hello")
      entry = post.audit_log_entries.created_events.first
      expect(entry.metadata).to include("title_upcase" => "HELLO")
    end
  end

  describe "multiple keys" do
    after { Post._audit_log_meta = nil }

    it "stores all keys in metadata" do
      Post.audit_log meta: { env: -> { "test" }, version: -> { "1" } }
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.created_events.first
      expect(entry.metadata).to include("env" => "test", "version" => "1")
    end
  end

  describe "merging with request metadata" do
    around do |ex|
      Post.audit_log meta: { source: -> { "model" } }
      RailsAuditLog.request_metadata = { "remote_ip" => "1.2.3.4" }
      ex.run
      Post._audit_log_meta = nil
      RailsAuditLog.request_metadata = nil
    end

    it "merges model meta with request metadata" do
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.created_events.first
      expect(entry.metadata).to include("source" => "model", "remote_ip" => "1.2.3.4")
    end
  end
end
