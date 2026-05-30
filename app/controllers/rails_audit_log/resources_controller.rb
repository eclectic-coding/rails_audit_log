module RailsAuditLog
  class ResourcesController < ApplicationController
    def show
      @item_type = params[:item_type]
      @item_id   = params[:item_id]
      @pagy, @entries = pagy(
        AuditLogEntry
          .where(item_type: @item_type, item_id: @item_id)
          .order(created_at: :asc)
      )
    end
  end
end
