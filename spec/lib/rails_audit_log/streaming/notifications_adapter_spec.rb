require "rails_helper"

RSpec.describe RailsAuditLog::Streaming::NotificationsAdapter do
  subject(:adapter) { described_class.new }

  let(:entry) do
    RailsAuditLog::AuditLogEntry.new(
      event: "create", item_type: "Post", item_id: 1,
      object_changes: { "title" => [nil, "Hello"] }
    )
  end

  it "instruments rails_audit_log.entry_created" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe(described_class::EVENT) do |*, payload|
      events << payload
    end

    adapter.publish(entry)

    expect(events.size).to eq(1)
    expect(events.first[:entry]).to eq(entry)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "exposes the EVENT constant" do
    expect(described_class::EVENT).to eq("rails_audit_log.entry_created")
  end
end
