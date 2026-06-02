module RailsAuditLog
  module Streaming
    class PublishEntryJob < ApplicationJob
      def perform(entry_attrs)
        entry = AuditLogEntry.new(entry_attrs)
        ActiveSupport::Notifications.instrument(
          NotificationsAdapter::EVENT,
          entry: entry
        )
      end
    end
  end
end
