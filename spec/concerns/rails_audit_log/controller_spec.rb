require "rails_helper"

RSpec.describe RailsAuditLog::Controller, type: :request do
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
