module RailsAuditLog
  # Represents a single audited event (+create+, +update+, or +destroy+) for
  # one ActiveRecord record.
  #
  # == Columns
  #
  # [event]               One of <tt>"create"</tt>, <tt>"update"</tt>, <tt>"destroy"</tt>.
  # [item_type]           Class name of the audited record (e.g. <tt>"Article"</tt>).
  # [item_id]             Primary key of the audited record.
  # [object_changes]      JSON hash of attribute changes in <tt>[from, to]</tt> form.
  #                       All three event types use the same format:
  #                       +create+ stores <tt>[nil, new]</tt> for every column,
  #                       +update+ stores <tt>[old, new]</tt> for changed columns only,
  #                       +destroy+ stores <tt>[final, nil]</tt> for every column.
  # [object]              JSON snapshot of the record's full attributes before the
  #                       change (stored when {RailsAuditLog.store_snapshot} is +true+).
  # [whodunnit_snapshot]  Display name of the actor at the time of the change.
  # [actor_type / actor_id] Polymorphic reference to the actor record.
  # [reason]              Optional free-text reason string.
  # [metadata]            Arbitrary JSON hash (request IP, custom lambdas, etc.).
  class AuditLogEntry < ApplicationRecord
    self.table_name = "audit_log_entries"

    EVENTS       = %w[create update destroy].freeze
    BLOB_COLUMNS = %w[object_changes object metadata].freeze
    PERIODS      = { "1h" => 1.hour, "24h" => 24.hours, "7d" => 7.days }.freeze

    # @api private
    def self.configure_connection!
      return unless (opts = RailsAuditLog.connects_to)

      connects_to(**opts)
    end

    belongs_to :item,  polymorphic: true, optional: true
    belongs_to :actor, polymorphic: true, optional: true

    validates :event,     presence: true, inclusion: { in: EVENTS }
    validates :item_type, presence: true
    validates :item_id,   presence: true
    validate  :metadata_must_be_a_hash

    # @!group Event scopes

    # Entries for +create+ events.
    # @return [ActiveRecord::Relation]
    scope :created_events,  -> { where(event: "create") }

    # Entries for +update+ events.
    # @return [ActiveRecord::Relation]
    scope :updated_events,  -> { where(event: "update") }

    # Entries for +destroy+ events.
    # @return [ActiveRecord::Relation]
    scope :destroyed_events, -> { where(event: "destroy") }

    # @deprecated Use {.created_events} instead.
    scope :creates,  -> { created_events }
    # @deprecated Use {.updated_events} instead.
    scope :updates,  -> { updated_events }
    # @deprecated Use {.destroyed_events} instead.
    scope :destroys, -> { destroyed_events }

    # @!endgroup

    # @!group Actor / resource scopes

    # Entries written by a specific actor.
    #
    # @param actor [ActiveRecord::Base] the actor record to filter by
    # @return [ActiveRecord::Relation]
    # @example
    #   AuditLogEntry.by_actor(current_user)
    scope :by_actor, ->(actor) { where(actor_type: actor.class.name, actor_id: actor.id) }

    # Entries for a specific resource class or instance.
    # Pass a class to get all entries for that type; pass an instance for one record.
    #
    # @param resource [Class, ActiveRecord::Base]
    # @return [ActiveRecord::Relation]
    # @example All entries for Article
    #   AuditLogEntry.for_resource(Article)
    # @example All entries for one article
    #   AuditLogEntry.for_resource(article)
    scope :for_resource, lambda { |resource|
      if resource.is_a?(Class)
        where(item_type: resource.name)
      else
        where(item_type: resource.class.name, item_id: resource.id)
      end
    }

    # @!endgroup

    # @!group Time scopes

    # Entries created at or after +time+.
    #
    # @param time [Time]
    # @return [ActiveRecord::Relation]
    scope :since, ->(time) { where(created_at: time..) }

    # Entries created at or before +time+.
    #
    # @param time [Time]
    # @return [ActiveRecord::Relation]
    scope :until, ->(time) { where(created_at: ..time) }

    # Entries within a named period. Valid keys: <tt>"1h"</tt>, <tt>"24h"</tt>, <tt>"7d"</tt>.
    #
    # @param period [String] one of +PERIODS.keys+
    # @return [ActiveRecord::Relation]
    scope :for_period, ->(period) { where(created_at: PERIODS[period].ago..) }

    # @!endgroup

    # Omits the three JSON blob columns (+object_changes+, +object+, +metadata+)
    # from the +SELECT+. Use on index/listing queries where blobs are not
    # displayed to reduce I/O and avoid deserializing large payloads.
    #
    # @return [ActiveRecord::Relation]
    scope :slim, -> { select(column_names - BLOB_COLUMNS) }

    # Entries where +object_changes+ contains a key matching +attribute+.
    # Uses <tt>json_extract</tt> on SQLite/MySQL and <tt>->></tt> on PostgreSQL.
    #
    # @param attribute [Symbol, String] the attribute name to filter on
    # @return [ActiveRecord::Relation]
    # @example
    #   AuditLogEntry.touching(:title)
    #   post.audit_log_entries.updated_events.touching(:published_at)
    scope :touching, ->(attribute) {
      if connection.adapter_name =~ /PostgreSQL/i
        # :nocov:
        where("object_changes->>? IS NOT NULL", attribute.to_s)
        # :nocov:
      else
        where("json_extract(object_changes, ?) IS NOT NULL", "$.#{attribute}")
      end
    }

    # Reconstructs and returns the record's state *before* this entry's change.
    # Uses the +object+ snapshot when available; falls back to deriving prior
    # state from +object_changes+ (or the live record for +update+ entries).
    #
    # @return [ActiveRecord::Base, nil] an unpersisted instance; +nil+ for
    #   +create+ entries (there is no prior state)
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

    # Returns the entry immediately before this one in the version chain for
    # the same record (lower +id+), or +nil+ if this is the first entry.
    #
    # @return [AuditLogEntry, nil]
    def previous
      self.class.where(item_type: item_type, item_id: item_id).where("id < ?", id).order(id: :desc).first
    end

    # Returns the entry immediately after this one in the version chain for
    # the same record (higher +id+), or +nil+ if this is the last entry.
    #
    # @return [AuditLogEntry, nil]
    def next
      self.class.where(item_type: item_type, item_id: item_id).where("id > ?", id).order(id: :asc).first
    end

    # Returns the list of attribute (and association) names that changed in
    # this entry, derived from the keys of +object_changes+.
    #
    # @return [Array<String>]
    def changed_attributes
      object_changes&.keys || []
    end

    # Returns +object_changes+ in a named-key format convenient for display.
    #
    # @return [Hash{String => Hash}] keys are attribute names; values are
    #   hashes with +:from+ and +:to+ keys
    # @example
    #   entry.diff
    #   # => { "title" => { from: "Old", to: "New" }, ... }
    def diff
      return {} unless object_changes

      object_changes.transform_values { |from_to| { from: from_to[0], to: from_to[1] } }
    end

    private

    def metadata_must_be_a_hash
      errors.add(:metadata, "must be a Hash") if metadata.present? && !metadata.is_a?(Hash)
    end
  end
end
