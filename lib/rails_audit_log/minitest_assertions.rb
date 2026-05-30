module RailsAuditLog
  module MinitestAssertions
    def assert_audit_log_entry(record, event: nil, touching: nil, message: nil)
      scope = build_scope(record, event, touching)
      msg   = message || default_message("to have", record, event, touching)
      assert scope.exists?, msg
    end

    def refute_audit_log_entry(record, event: nil, touching: nil, message: nil)
      scope = build_scope(record, event, touching)
      msg   = message || default_message("not to have", record, event, touching)
      refute scope.exists?, msg
    end

    private

    def build_scope(record, event, touching)
      scope = record.audit_log_entries
      scope = scope.where(event: event.to_s) if event
      scope = scope.touching(touching)       if touching
      scope
    end

    def default_message(polarity, record, event, touching)
      parts = []
      parts << " with event '#{event}'" if event
      parts << " touching '#{touching}'" if touching
      "Expected #{record.class}##{record.id} #{polarity} an audit log entry#{parts.join}"
    end
  end
end
