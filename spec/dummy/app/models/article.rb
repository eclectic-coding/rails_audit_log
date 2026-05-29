class Article < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log only: [:title], meta: { model: -> { "Article" }, title_length: ->(record) { record.title.length } }
end
