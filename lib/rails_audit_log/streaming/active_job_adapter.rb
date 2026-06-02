module RailsAuditLog
  module Streaming
    # Publishes each audit entry asynchronously by enqueuing
    # {RailsAuditLog::Streaming::PublishEntryJob}. The job fires a
    # +rails_audit_log.entry_created+ notification when performed, so subscribers
    # receive the entry out-of-band without blocking the request.
    #
    # @example
    #   RailsAuditLog.streaming_adapter = RailsAuditLog::Streaming::ActiveJobAdapter.new
    #
    #   # Custom queue:
    #   RailsAuditLog.streaming_adapter = RailsAuditLog::Streaming::ActiveJobAdapter.new(queue: :streaming)
    class ActiveJobAdapter
      def initialize(queue: nil)
        @queue = queue
      end

      def publish(entry)
        job = RailsAuditLog::Streaming::PublishEntryJob
        job = job.set(queue: @queue) if @queue
        job.perform_later(entry.attributes.compact)
      end
    end
  end
end
