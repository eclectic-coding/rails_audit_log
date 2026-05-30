module RailsAuditLog
  class AuditLogEntriesController < ApplicationController
    def index
      @entries = AuditLogEntry.order(created_at: :desc)
    end

    def show
      @entry = AuditLogEntry.find(params[:id])
    end
  end
end
