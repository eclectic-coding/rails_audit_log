module RailsAuditLog
  class WriteAuditLogJob < ApplicationJob
    def perform(entry_attrs, version_limit: nil)
      AuditLogEntry.create!(entry_attrs)

      return unless version_limit

      item_type = entry_attrs["item_type"]
      item_id   = entry_attrs["item_id"]
      count     = AuditLogEntry.where(item_type: item_type, item_id: item_id).count
      excess    = count - version_limit
      return unless excess > 0

      AuditLogEntry.where(item_type: item_type, item_id: item_id)
                   .order(id: :asc)
                   .limit(excess)
                   .delete_all
    end
  end
end
