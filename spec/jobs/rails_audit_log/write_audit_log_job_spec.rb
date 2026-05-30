require "rails_helper"

RSpec.describe RailsAuditLog::WriteAuditLogJob, type: :job do
  let(:post) { Post.create!(title: "job test") }

  before { post }  # force eager creation so it doesn't land inside expect blocks

  let(:base_attrs) do
    {
      "event"              => "update",
      "item_type"          => "Post",
      "item_id"            => post.id,
      "object_changes"     => { "title" => ["old", "new"] },
      "object"             => nil,
      "reason"             => nil,
      "metadata"           => nil,
      "whodunnit_snapshot" => nil,
      "actor_type"         => nil,
      "actor_id"           => nil
    }
  end

  it "creates an AuditLogEntry with the given attributes" do
    expect {
      described_class.perform_now(base_attrs)
    }.to change(RailsAuditLog::AuditLogEntry, :count).by(1)

    entry = RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id).last
    expect(entry.event).to eq("update")
    expect(entry.object_changes["title"]).to eq(["old", "new"])
  end

  it "does not prune when version_limit is nil" do
    3.times { |i| described_class.perform_now(base_attrs.merge("object_changes" => { "title" => ["v#{i}", "v#{i + 1}"] })) }

    expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id).count).to be >= 3
  end

  it "prunes oldest entries when version_limit is set" do
    existing = post.audit_log_entries.count
    2.times { |i| described_class.perform_now(base_attrs.merge("object_changes" => { "title" => ["v#{i}", "v#{i + 1}"] })) }

    described_class.perform_now(base_attrs, version_limit: existing + 2)

    expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id).count)
      .to eq(existing + 2)
  end

  it "scopes pruning to the specific record" do
    other_post = Post.create!(title: "other")
    3.times { |i| described_class.perform_now(base_attrs.merge("object_changes" => { "title" => ["v#{i}", "v#{i + 1}"] })) }

    described_class.perform_now(base_attrs, version_limit: 2)

    expect(RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id).count).to eq(2)
    expect(other_post.audit_log_entries.count).to eq(1)
  end
end
