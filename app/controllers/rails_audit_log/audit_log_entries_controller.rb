module RailsAuditLog
  class AuditLogEntriesController < ApplicationController
    def index
      @pagy, @entries = pagy(AuditLogEntry.order(created_at: :desc))
    end

    def resource
      @item_type = params[:item_type]
      @item_id   = params[:item_id]
      @pagy, @entries = pagy(
        AuditLogEntry
          .where(item_type: @item_type, item_id: @item_id)
          .order(created_at: :asc)
      )
    end

    def show
      @entry = AuditLogEntry.find(params[:id])
    end
  end
end
