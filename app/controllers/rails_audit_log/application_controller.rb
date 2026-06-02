module RailsAuditLog
  # @api private
  class ApplicationController < ActionController::Base
    include Pagy::Method

    protect_from_forgery with: :exception
    before_action :authenticate!

    private

    def authenticate!
      return unless (auth = RailsAuditLog.authenticate)

      instance_exec(self, &auth) || request_http_basic_authentication("Audit Log")
    end

    def base_audit_scope
      tenant_id = RailsAuditLog.current_tenant&.call
      tenant_id ? AuditLogEntry.for_tenant(tenant_id) : AuditLogEntry.all
    end
  end
end
