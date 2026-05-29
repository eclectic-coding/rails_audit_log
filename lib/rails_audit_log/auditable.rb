module RailsAuditLog
  module Auditable
    extend ActiveSupport::Concern

    included do
      has_many :audit_log_entries,
               class_name: "RailsAuditLog::AuditLogEntry",
               as: :item,
               dependent: :destroy

      after_create  :record_audit_create
      after_update  :record_audit_update
      after_destroy :record_audit_destroy
    end

    private

    def record_audit_create
      record_audit_entry("create", saved_changes)
    end

    def record_audit_update
      record_audit_entry("update", saved_changes)
    end

    def record_audit_destroy
      changes = attributes.transform_values { |v| [v, nil] }
      record_audit_entry("destroy", changes)
    end

    def record_audit_entry(event, changes)
      actor = RailsAuditLog.actor
      RailsAuditLog::AuditLogEntry.create!(
        event:          event,
        item_type:      self.class.name,
        item_id:        id,
        object_changes: changes,
        actor_type:     actor&.class&.name,
        actor_id:       actor.respond_to?(:id) ? actor.id : nil
      )
    end
  end
end
