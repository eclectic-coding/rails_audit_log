module RailsAuditLog
  class AuditLogEntry < ApplicationRecord
    self.table_name = "audit_log_entries"

    EVENTS = %w[create update destroy].freeze

    belongs_to :item, polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true

    validates :event, presence: true, inclusion: { in: EVENTS }
    validates :item_type, presence: true
    validates :item_id, presence: true
    validate :metadata_must_be_a_hash

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

    # Instance methods

    def reify
      return nil if event == "create"

      klass = item_type.constantize

      if object.present?
        instance = klass.new
        instance.assign_attributes(object.except("id"))
        instance.id = object.fetch("id") { item_id }
        return instance
      end

      # Fallback: diff-only mode or entries recorded before snapshot support.
      # Filter to column names so association-change entries (e.g. tags, comments)
      # don't get assigned to the record as if they were scalar attributes.
      column_names = klass.column_names.map(&:to_s)
      from_attrs = (object_changes || {})
        .select { |k, _| column_names.include?(k) }
        .transform_values { |from_to| from_to[0] }

      if event == "update"
        record = klass.find_by(id: item_id)
        from_attrs = record.attributes.merge(from_attrs) if record
      end

      instance = klass.new
      instance.assign_attributes(from_attrs.except("id"))
      instance.id = from_attrs.fetch("id") { item_id }
      instance
    end

    def previous
      self.class.where(item_type: item_type, item_id: item_id).where("id < ?", id).order(id: :desc).first
    end

    def next
      self.class.where(item_type: item_type, item_id: item_id).where("id > ?", id).order(id: :asc).first
    end

    def changed_attributes
      object_changes&.keys || []
    end

    def diff
      return {} unless object_changes

      object_changes.transform_values { |from_to| { from: from_to[0], to: from_to[1] } }
    end

    private

    def metadata_must_be_a_hash
      errors.add(:metadata, "must be a Hash") if metadata.present? && !metadata.is_a?(Hash)
    end

    public

    # Attribute scope — uses json_extract (SQLite/MySQL) or ->> (PostgreSQL)
    scope :touching, ->(attribute) {
      if connection.adapter_name =~ /PostgreSQL/i
        # :nocov:
        where("object_changes->>? IS NOT NULL", attribute.to_s)
        # :nocov:
      else
        where("json_extract(object_changes, ?) IS NOT NULL", "$.#{attribute}")
      end
    }
  end
end
