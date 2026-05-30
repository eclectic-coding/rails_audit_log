require "turbo-rails"
require "importmap-rails"

module RailsAuditLog
  class Engine < ::Rails::Engine
    isolate_namespace RailsAuditLog

    initializer "rails_audit_log.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/javascript")
      end
    end

    initializer "rails_audit_log.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << root.join("app/javascript")
      end
    end

    initializer "rails_audit_log.connect_audit_db" do
      ActiveSupport.on_load(:active_record) do
        RailsAuditLog::AuditLogEntry.configure_connection!
      end
    end
  end
end
