require "rails_helper"

RSpec.describe RailsAuditLog::Controller, type: :request do
  describe "request metadata capture" do
    around do |ex|
      RailsAuditLog.capture_request_metadata = true
      ex.run
      RailsAuditLog.capture_request_metadata = false
    end

    it "stores remote_ip and user_agent on the entry's metadata" do
      post posts_path, params: { title: "Hello" },
                       headers: { "HTTP_USER_AGENT" => "TestBrowser/1.0" }
      entry = RailsAuditLog::AuditLogEntry.last
      expect(entry.metadata).to include("remote_ip", "user_agent")
      expect(entry.metadata["user_agent"]).to eq("TestBrowser/1.0")
    end

    it "clears request_metadata after the request" do
      post posts_path, params: { title: "Hello" }
      expect(RailsAuditLog.request_metadata).to be_nil
    end

    it "does not populate metadata when capture_request_metadata is false" do
      RailsAuditLog.capture_request_metadata = false
      post posts_path, params: { title: "Hello" }
      entry = RailsAuditLog::AuditLogEntry.last
      expect(entry.metadata).to be_nil
    end
  end

  describe "audit_log_actor" do
    it "sets the actor on the thread during the request" do
      user = User.create!(name: "Alice")
      post posts_path, params: { title: "Hello", user_id: user.id }
      entry = RailsAuditLog::AuditLogEntry.last
      expect(entry.actor_type).to eq("User")
      expect(entry.actor_id).to eq(user.id)
    end

    it "clears the actor after the request" do
      user = User.create!(name: "Alice")
      post posts_path, params: { title: "Hello", user_id: user.id }
      expect(RailsAuditLog.actor).to be_nil
    end

    it "records no actor when the block returns nil" do
      post posts_path, params: { title: "Hello" }
      entry = RailsAuditLog::AuditLogEntry.last
      expect(entry.actor_type).to be_nil
      expect(entry.actor_id).to be_nil
    end
  end
end
