require "rails_helper"

RSpec.describe "AuditLogEntry#whodunnit_snapshot" do
  let(:user) { User.create!(name: "Alice") }
  let(:post) { Post.create!(title: "Hello") }

  it "stores the actor display name at write time" do
    RailsAuditLog.with_actor(user) { post.update!(title: "Updated") }
    entry = post.audit_log_entries.updated_events.first
    expect(entry.whodunnit_snapshot).to eq("Alice")
  end

  it "is nil when no actor is set" do
    post.update!(title: "No actor")
    entry = post.audit_log_entries.updated_events.first
    expect(entry.whodunnit_snapshot).to be_nil
  end

  it "persists the name even after the actor record is deleted" do
    RailsAuditLog.with_actor(user) { post.update!(title: "By Alice") }
    entry = post.audit_log_entries.updated_events.first
    user.destroy
    expect(entry.reload.whodunnit_snapshot).to eq("Alice")
  end

  it "falls back to to_s for actors without a name method" do
    actor = Object.new
    def actor.to_s = "custom_actor"

    RailsAuditLog.with_actor(actor) { post.update!(title: "By custom") }
    entry = post.audit_log_entries.updated_events.first
    expect(entry.whodunnit_snapshot).to eq("custom_actor")
  end

  describe "RailsAuditLog.whodunnit_display" do
    around do |ex|
      original = RailsAuditLog.whodunnit_display
      ex.run
      RailsAuditLog.whodunnit_display = original
    end

    it "can be customised with a proc" do
      RailsAuditLog.whodunnit_display = ->(actor) { "user:#{actor.id}" }
      RailsAuditLog.with_actor(user) { post.update!(title: "Custom display") }
      entry = post.audit_log_entries.updated_events.first
      expect(entry.whodunnit_snapshot).to eq("user:#{user.id}")
    end
  end
end
