class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log associations: true
  has_paper_trail if defined?(PaperTrail)
  has_many :comments, dependent: :destroy
  has_and_belongs_to_many :tags, join_table: :post_tags
end
