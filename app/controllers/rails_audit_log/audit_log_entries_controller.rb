module RailsAuditLog
  class AuditLogEntriesController < ApplicationController
    def index
      set_filters
      @pagy, @entries = pagy(filtered_scope)
      @item_types     = AuditLogEntry.distinct.order(:item_type).pluck(:item_type)
    end

    def show
      @entry = AuditLogEntry.find(params[:id])
    end

    private

    def set_filters
      @event     = params[:event].presence_in(AuditLogEntry::EVENTS)
      @item_type = params[:item_type].presence
      @period    = params[:period].presence_in(AuditLogEntry::PERIODS.keys)
      @q         = params[:q].presence
    end

    def filtered_scope
      scope = AuditLogEntry.order(created_at: :desc)
      scope = scope.where(event: @event)                          if @event
      scope = scope.where(item_type: @item_type)                  if @item_type
      scope = scope.for_period(@period)                           if @period
      scope = scope.where("whodunnit_snapshot LIKE ?", "%#{@q}%") if @q
      scope
    end
  end
end
