require "rails_helper"

RSpec.describe "RailsAuditLog.version_at" do
  let!(:post) { Post.create!(title: "v1", body: "original") }
  let(:t_create) { post.audit_log_entries.created_events.first.created_at }

  it "returns nil when no entries exist at or before the given time" do
    expect(RailsAuditLog.version_at(post, 1.year.ago)).to be_nil
  end

  it "returns the created state when called at the create timestamp" do
    result = RailsAuditLog.version_at(post, t_create)
    expect(result).to be_a(Post)
    expect(result).not_to be_persisted
    expect(result.title).to eq("v1")
  end

  it "returns the created state for a time between create and first update" do
    post.update!(title: "v2")
    post.audit_log_entries.updated_events.first.update_columns(created_at: 1.hour.from_now)
    result = RailsAuditLog.version_at(post, t_create + 30.minutes)
    expect(result.title).to eq("v1")
  end

  it "returns the updated state after an update" do
    post.update!(title: "v2")
    t_update = 1.hour.from_now
    post.audit_log_entries.updated_events.first.update_columns(created_at: t_update)
    result = RailsAuditLog.version_at(post, t_update)
    expect(result.title).to eq("v2")
  end

  it "returns the correct state when multiple updates exist" do
    post.update!(title: "v2")
    post.update!(title: "v3")
    entries = post.audit_log_entries.updated_events.order(:id)
    t_update1 = 1.hour.from_now
    t_update2 = 2.hours.from_now
    entries[0].update_columns(created_at: t_update1)
    entries[1].update_columns(created_at: t_update2)

    expect(RailsAuditLog.version_at(post, t_update1).title).to eq("v2")
    expect(RailsAuditLog.version_at(post, t_update2).title).to eq("v3")
  end

  it "preserves untracked attributes in the state via the snapshot" do
    post.update!(title: "v2")
    t_update = post.audit_log_entries.updated_events.first.created_at
    result = RailsAuditLog.version_at(post, t_update)
    expect(result.body).to eq("original")
  end

  it "returns nil when the record was destroyed at or before the given time" do
    post.destroy
    destroy_entry = RailsAuditLog::AuditLogEntry.destroyed_events.last
    expect(RailsAuditLog.version_at(post, destroy_entry.created_at)).to be_nil
  end

  it "sets the id on the returned instance" do
    result = RailsAuditLog.version_at(post, t_create)
    expect(result.id).to eq(post.id)
  end
end
