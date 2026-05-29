class Article < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log only: [:title]
end
