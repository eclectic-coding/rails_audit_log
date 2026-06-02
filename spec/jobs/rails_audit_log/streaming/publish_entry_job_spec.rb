require "rails_helper"

RSpec.describe RailsAuditLog::Streaming::PublishEntryJob do
  it "instruments rails_audit_log.entry_created with an AuditLogEntry" do
    events = []
    subscription = ActiveSupport::Notifications.subscribe(
      RailsAuditLog::Streaming::NotificationsAdapter::EVENT
    ) { |*, payload| events << payload }

    described_class.perform_now(
      "event" => "create", "item_type" => "Post", "item_id" => 1
    )

    expect(events.size).to eq(1)
    entry = events.first[:entry]
    expect(entry).to be_a(RailsAuditLog::AuditLogEntry)
    expect(entry.event).to eq("create")
    expect(entry.item_type).to eq("Post")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
