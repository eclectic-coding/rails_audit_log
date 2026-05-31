namespace :rails_audit_log do
  desc "Prune audit log entries that exceed the configured retention_period or version_limit. " \
       "Delegates to RailsAuditLog::PruneAuditLogJob."
  task prune: :environment do
    RailsAuditLog::PruneAuditLogJob.perform_now
  end
end
