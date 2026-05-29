require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "#metadata" do
  let(:post) { Post.create!(title: "Hello") }

  def entry(metadata: nil)
    described_class.create!(event: "update", item_type: "Post", item_id: post.id, metadata: metadata)
  end

  it "defaults to nil" do
    expect(entry.metadata).to be_nil
  end

  it "stores an arbitrary key/value hash" do
    e = entry(metadata: { "reason" => "legal review", "ticket" => "JIRA-123" })
    expect(e.reload.metadata).to eq("reason" => "legal review", "ticket" => "JIRA-123")
  end

  it "stores nested values" do
    e = entry(metadata: { "context" => { "ip" => "1.2.3.4" } })
    expect(e.reload.metadata).to eq("context" => { "ip" => "1.2.3.4" })
  end

  it "is invalid when metadata is not a Hash" do
    e = described_class.new(event: "update", item_type: "Post", item_id: post.id, metadata: "not a hash")
    expect(e).not_to be_valid
    expect(e.errors[:metadata]).to include("must be a Hash")
  end

  it "is valid when metadata is nil" do
    expect(entry(metadata: nil)).to be_valid
  end

  it "is valid when metadata is an empty hash" do
    expect(entry(metadata: {})).to be_valid
  end
end
