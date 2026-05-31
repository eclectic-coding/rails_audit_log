module RailsAuditLog
  # Opt-in Minitest assertions for audit log expectations.
  #
  # == Setup
  #
  #   # test/test_helper.rb
  #   require "rails_audit_log/minitest_assertions"
  #
  #   class ActiveSupport::TestCase
  #     include RailsAuditLog::MinitestAssertions
  #   end
  #
  # == Usage
  #
  #   assert_audit_log_entry(post, event: :update, touching: :title)
  #   refute_audit_log_entry(post, event: :create)
  module MinitestAssertions
    # Asserts that +record+ has at least one {AuditLogEntry} matching the
    # given filters. Fails with a descriptive message when no entry is found.
    #
    # @param record [ActiveRecord::Base] the audited record to check
    # @param event [Symbol, String, nil] optional event filter
    #   (<tt>:create</tt>, <tt>:update</tt>, or <tt>:destroy</tt>)
    # @param touching [Symbol, String, nil] optional attribute name filter
    # @param message [String, nil] custom failure message; auto-generated when nil
    # @return [void]
    # @example
    #   assert_audit_log_entry(post, event: :update, touching: :title)
    def assert_audit_log_entry(record, event: nil, touching: nil, message: nil)
      scope = build_scope(record, event, touching)
      msg   = message || default_message("to have", record, event, touching)
      assert scope.exists?, msg
    end

    # Asserts that +record+ has *no* {AuditLogEntry} matching the given filters.
    # Fails with a descriptive message when a matching entry is found.
    #
    # @param record [ActiveRecord::Base] the audited record to check
    # @param event [Symbol, String, nil] optional event filter
    # @param touching [Symbol, String, nil] optional attribute name filter
    # @param message [String, nil] custom failure message; auto-generated when nil
    # @return [void]
    # @example
    #   refute_audit_log_entry(post, event: :destroy)
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
