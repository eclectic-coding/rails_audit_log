module RailsAuditLog
  class AuditLogEntriesController < ApplicationController
    PER_PAGE = 25

    def index
      scope   = AuditLogEntry.order(created_at: :desc)
      @total  = scope.count
      @total_pages = [(@total.to_f / PER_PAGE).ceil, 1].max
      @page   = [[params.fetch(:page, 1).to_i, 1].max, @total_pages].min
      @entries = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
    end

    def show
      @entry = AuditLogEntry.find(params[:id])
    end
  end
end
