module RailsAuditLog
  module TestHelpers
    def without_audit_log(&block)
      RailsAuditLog.disable(&block)
    end
  end
end
