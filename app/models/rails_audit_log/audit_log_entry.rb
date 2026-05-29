module RailsAuditLog
  class AuditLogEntry < ApplicationRecord
    self.table_name = "audit_log_entries"

    EVENTS = %w[create update destroy].freeze

    belongs_to :item, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true

    validates :event, presence: true, inclusion: { in: EVENTS }
    validates :item_type, presence: true
    validates :item_id, presence: true

    # Event scopes
    scope :created_events,  -> { where(event: "create") }
    scope :updated_events,  -> { where(event: "update") }
    scope :destroyed_events, -> { where(event: "destroy") }

    # Deprecated short aliases kept for backwards compatibility

    scope :creates,  -> { created_events }
    scope :updates,  -> { updated_events }
    scope :destroys, -> { destroyed_events }

    # Actor / resource scopes
    scope :by_actor, ->(actor) { where(actor_type: actor.class.name, actor_id: actor.id) }
    scope :for_resource, lambda { |resource|
      if resource.is_a?(Class)
        where(item_type: resource.name)
      else
        where(item_type: resource.class.name, item_id: resource.id)
      end
    }

    # Time scopes
    scope :since, ->(time) { where(created_at: time..) }
    scope :until, ->(time) { where(created_at: ..time) }

    # Attribute scope — uses json_extract (SQLite/MySQL) or json ? key (PostgreSQL)
    scope :touching, ->(attribute) {
      if connection.adapter_name =~ /PostgreSQL/i
        # :nocov:
        where("object_changes ? :key", key: attribute.to_s)
        # :nocov:
      else
        where("json_extract(object_changes, ?) IS NOT NULL", "$.#{attribute}")
      end
    }
  end
end
