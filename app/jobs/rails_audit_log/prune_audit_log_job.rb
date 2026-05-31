module RailsAuditLog
  # Background job that prunes {AuditLogEntry} records for every audited model
  # that has a configured retention policy.
  #
  # Enqueue on a recurring schedule via your job backend (Solid Queue,
  # Sidekiq, GoodJob, etc.):
  #
  #   RailsAuditLog::PruneAuditLogJob.perform_later
  #
  # The job iterates over every +item_type+ present in +audit_log_entries+,
  # resolves the effective +retention_period+ / +version_limit+ for that model,
  # and deletes entries that exceed either constraint. Pruning is always scoped
  # to one +item_type+ at a time so models do not interfere with each other.
  class PruneAuditLogJob < ApplicationJob
    def perform
      AuditLogEntry.distinct.pluck(:item_type).each do |item_type|
        prune_item_type(item_type)
      end
    end

    private

    def prune_item_type(item_type)
      klass  = item_type.safe_constantize
      period = resolve_period(klass)
      limit  = resolve_limit(klass)
      return unless period || limit

      scope = AuditLogEntry.where(item_type: item_type)

      scope.where(created_at: ..period.ago).delete_all if period

      return unless limit

      scope.select(:item_id).distinct.pluck(:item_id).each do |item_id|
        record_scope = scope.where(item_id: item_id)
        excess       = record_scope.count - limit
        record_scope.order(id: :asc).limit(excess).delete_all if excess > 0
      end
    end

    def resolve_period(klass)
      if klass.respond_to?(:_audit_log_retain_for)
        klass._audit_log_retain_for || RailsAuditLog.retention_period
      else
        RailsAuditLog.retention_period
      end
    end

    def resolve_limit(klass)
      if klass.respond_to?(:_audit_log_version_limit)
        klass._audit_log_version_limit || RailsAuditLog.version_limit
      else
        RailsAuditLog.version_limit
      end
    end
  end
end
