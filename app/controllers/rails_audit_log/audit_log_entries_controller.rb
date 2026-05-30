module RailsAuditLog
  class AuditLogEntriesController < ApplicationController
    PERIODS = { "1h" => 1.hour, "24h" => 24.hours, "7d" => 7.days }.freeze

    def index
      set_filters
      @pagy, @entries = pagy(filtered_scope)
      @item_types     = AuditLogEntry.distinct.order(:item_type).pluck(:item_type)
      @event_options  = AuditLogEntry::EVENTS.map(&:to_s)
      @period_options = PERIODS.keys
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

    private

    def set_filters
      @event     = params[:event].presence_in(AuditLogEntry::EVENTS.map(&:to_s))
      @item_type = params[:item_type].presence
      @period    = params[:period].presence_in(PERIODS.keys)
      @q         = params[:q].presence
    end

    def filtered_scope
      scope = AuditLogEntry.order(created_at: :desc)
      scope = scope.where(event: @event)                              if @event
      scope = scope.where(item_type: @item_type)                      if @item_type
      scope = scope.where(created_at: PERIODS[@period].ago..)         if @period
      scope = scope.where("whodunnit_snapshot LIKE ?", "%#{@q}%")     if @q
      scope
    end
  end
end
