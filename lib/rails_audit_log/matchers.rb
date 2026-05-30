module RailsAuditLog
  module Matchers
    def have_audit_log_entry(event = nil)
      HaveAuditLogEntry.new(event)
    end

    def create_audit_log_entry(event: nil, touching: nil)
      CreateAuditLogEntry.new(event: event, touching: touching)
    end

    class HaveAuditLogEntry
      def initialize(event)
        @event    = event
        @touching = nil
      end

      def touching(attribute)
        @touching = attribute
        self
      end

      def matches?(record)
        @record = record
        scope = record.audit_log_entries
        scope = scope.where(event: @event.to_s) if @event
        scope = scope.touching(@touching)       if @touching
        scope.exists?
      end

      def failure_message
        "expected #{@record.class}##{@record.id} to have an audit log entry#{qualifier}"
      end

      def failure_message_when_negated
        "expected #{@record.class}##{@record.id} not to have an audit log entry#{qualifier}"
      end

      def description
        "have an audit log entry#{qualifier}"
      end

      private

      def qualifier
        parts = []
        parts << " with event '#{@event}'" if @event
        parts << " touching '#{@touching}'" if @touching
        parts.join
      end
    end

    class CreateAuditLogEntry
      def initialize(event:, touching:)
        @event    = event
        @touching = touching
      end

      def touching(attribute)
        @touching = attribute
        self
      end

      def supports_block_expectations?
        true
      end

      def matches?(block)
        @before = matching_scope.count
        block.call
        @after = matching_scope.count
        @after > @before
      end

      def failure_message
        "expected block to create an audit log entry#{qualifier}, but none was created"
      end

      def failure_message_when_negated
        "expected block not to create an audit log entry#{qualifier}, but one was created"
      end

      def description
        "create an audit log entry#{qualifier}"
      end

      private

      def matching_scope
        scope = RailsAuditLog::AuditLogEntry.all
        scope = scope.where(event: @event.to_s) if @event
        scope = scope.touching(@touching)       if @touching
        scope
      end

      def qualifier
        parts = []
        parts << " with event '#{@event}'" if @event
        parts << " touching '#{@touching}'" if @touching
        parts.join
      end
    end
  end
end
