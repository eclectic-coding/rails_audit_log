module RailsAuditLog
  module Auditable
    extend ActiveSupport::Concern

    included do
      class_attribute :_audit_log_only,   default: nil
      class_attribute :_audit_log_ignore, default: nil

      has_many :audit_log_entries,
               class_name: "RailsAuditLog::AuditLogEntry",
               as: :item,
               dependent: :destroy

      after_create  :record_audit_create
      after_update  :record_audit_update
      after_destroy :record_audit_destroy
    end

    class_methods do
      def audit_log(only: nil, ignore: nil)
        self._audit_log_only   = only.map(&:to_s)   if only
        self._audit_log_ignore = ignore.map(&:to_s) if ignore
      end
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
      filtered = filter_changes(changes)
      return if filtered.empty? && event == "update"

      actor = RailsAuditLog.actor
      RailsAuditLog::AuditLogEntry.create!(
        event:          event,
        item_type:      self.class.name,
        item_id:        id,
        object_changes: filtered,
        actor_type:     actor&.class&.name,
        actor_id:       actor.respond_to?(:id) ? actor.id : nil
      )
    end

    def filter_changes(changes)
      result = changes.dup

      if self.class._audit_log_only
        result.select! { |k, _| self.class._audit_log_only.include?(k) }
      else
        ignored = self.class._audit_log_ignore || RailsAuditLog.ignored_attributes
        result.reject! { |k, _| ignored.include?(k) }
      end

      result
    end
  end
end
