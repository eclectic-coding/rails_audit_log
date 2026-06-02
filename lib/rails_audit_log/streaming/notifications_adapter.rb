module RailsAuditLog
  module Streaming
    # Publishes each audit entry synchronously via +ActiveSupport::Notifications+.
    # Zero external dependencies — subscribe with +ActiveSupport::Notifications.subscribe+.
    #
    # @example
    #   RailsAuditLog.streaming_adapter = RailsAuditLog::Streaming::NotificationsAdapter.new
    #
    #   ActiveSupport::Notifications.subscribe("rails_audit_log.entry_created") do |*, payload|
    #     entry = payload[:entry]
    #     Rails.logger.info "Audit: #{entry.event} on #{entry.item_type}##{entry.item_id}"
    #   end
    class NotificationsAdapter
      EVENT = "rails_audit_log.entry_created"

      def publish(entry)
        ActiveSupport::Notifications.instrument(EVENT, entry: entry)
      end
    end
  end
end
