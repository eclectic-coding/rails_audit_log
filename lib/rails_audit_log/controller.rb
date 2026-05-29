module RailsAuditLog
  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :set_audit_log_actor
      after_action  :clear_audit_log_actor
    end

    class_methods do
      def audit_log_actor(&block)
        @audit_log_actor_block = block
      end

      def audit_log_actor_block
        @audit_log_actor_block
      end
    end

    private

    def set_audit_log_actor
      block = self.class.audit_log_actor_block
      RailsAuditLog.actor = instance_exec(&block) if block
    end

    def clear_audit_log_actor
      RailsAuditLog.actor = nil
    end
  end
end
