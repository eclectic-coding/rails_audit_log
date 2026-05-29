module RailsAuditLog
  class AuditLogEntry < ApplicationRecord
    self.table_name = "audit_log_entries"

    EVENTS = %w[create update destroy].freeze

    belongs_to :item, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true

    validates :event, presence: true, inclusion: { in: EVENTS }
    validates :item_type, presence: true
    validates :item_id, presence: true

    scope :creates,  -> { where(event: "create") }
    scope :updates,  -> { where(event: "update") }
    scope :destroys, -> { where(event: "destroy") }
  end
end
