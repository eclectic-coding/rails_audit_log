class AuditEntriesController < ApplicationController
  def index
    @entries = RailsAuditLog::AuditLogEntry
      .order(created_at: :desc)
      .limit(50)
  end
end
