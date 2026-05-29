class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log associations: true
  has_many :comments, dependent: :destroy
end
