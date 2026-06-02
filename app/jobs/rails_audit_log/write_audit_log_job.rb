module RailsAuditLog
  class WriteAuditLogJob < ApplicationJob
    def perform(entry_attrs, version_limit: nil, retention_period: nil)
      entry = AuditLogEntry.create!(entry_attrs)
      RailsAuditLog.publish_entry(entry)

      item_type = entry_attrs["item_type"]
      item_id   = entry_attrs["item_id"]
      scope     = AuditLogEntry.where(item_type: item_type, item_id: item_id)

      if retention_period
        scope.where(created_at: ..retention_period.ago).delete_all
      end

      if version_limit
        count  = scope.count
        excess = count - version_limit
        scope.order(id: :asc).limit(excess).delete_all if excess > 0
      end
    end
  end
end
