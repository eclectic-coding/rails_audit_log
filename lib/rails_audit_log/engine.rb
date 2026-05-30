module RailsAuditLog
  class Engine < ::Rails::Engine
    isolate_namespace RailsAuditLog

    initializer "rails_audit_log.connect_audit_db" do
      ActiveSupport.on_load(:active_record) do
        RailsAuditLog::AuditLogEntry.configure_connection!
      end
    end
  end
end
