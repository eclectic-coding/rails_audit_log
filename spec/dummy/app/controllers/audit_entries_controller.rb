class AuditEntriesController < ApplicationController
  def index
    @entries = RailsAuditLog::AuditLogEntry
      .order(created_at: :desc)
      .limit(50)

    # Slim entries: header columns only (no object_changes / object / metadata)
    @slim_entries = RailsAuditLog::AuditLogEntry
      .slim
      .order(created_at: :desc)
      .limit(10)
  end
end
