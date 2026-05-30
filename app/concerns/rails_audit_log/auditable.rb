module RailsAuditLog
  module Auditable
    extend ActiveSupport::Concern

    included do
      class_attribute :_audit_log_only,          default: nil
      class_attribute :_audit_log_ignore,         default: nil
      class_attribute :_audit_log_meta,           default: nil
      class_attribute :_audit_log_associations,   default: nil
      class_attribute :_audit_log_version_limit,  default: nil
      class_attribute :_audit_log_async,          default: false

      has_many :audit_log_entries,
               class_name: "RailsAuditLog::AuditLogEntry",
               as: :item,
               dependent: :destroy

      after_create  :record_audit_create
      after_update  :record_audit_update
      after_destroy :record_audit_destroy

      # Intercept has_many (including :through) and has_and_belongs_to_many to
      # inject after_add/after_remove callbacks when association tracking is
      # enabled. Must be defined after has_many :audit_log_entries so that the
      # internal association is not affected.
      def self.has_many(name, scope = nil, **options, &extension)
        if _audit_log_associations && name.to_s != "audit_log_entries"
          options = _build_audit_association_options(name.to_s, options)
        end
        scope ? super(name, scope, **options, &extension) : super(name, **options, &extension)
      end

      def self.has_and_belongs_to_many(name, scope = nil, **options, &extension)
        if _audit_log_associations
          options = _build_audit_association_options(name.to_s, options)
        end
        scope ? super(name, scope, **options, &extension) : super(name, **options, &extension)
      end

      def self._build_audit_association_options(assoc_name, options)
        tracked = _audit_log_associations == true ||
                  Array(_audit_log_associations).map(&:to_s).include?(assoc_name)
        return options unless tracked

        add_cb    = ->(owner, rec) { owner.send(:record_audit_association_change, assoc_name, nil, { "id" => rec.id, "type" => rec.class.name }) }
        remove_cb = ->(owner, rec) { owner.send(:record_audit_association_change, assoc_name, { "id" => rec.id, "type" => rec.class.name }, nil) }
        options.merge(
          after_add:    [*options[:after_add]]    + [add_cb],
          after_remove: [*options[:after_remove]] + [remove_cb]
        )
      end
    end

    class_methods do
      def audit_log(only: nil, ignore: nil, meta: nil, associations: nil, version_limit: nil, async: nil)
        self._audit_log_only          = only.map(&:to_s)   if only
        self._audit_log_ignore        = ignore.map(&:to_s) if ignore
        self._audit_log_meta          = meta                if meta
        self._audit_log_associations  = associations        unless associations.nil?
        self._audit_log_version_limit = version_limit       unless version_limit.nil?
        self._audit_log_async         = async               unless async.nil?
      end
    end

    def skip_audit_log
      RailsAuditLog.disable { yield }
    end

    private

    def record_audit_create
      record_audit_entry("create", saved_changes, nil)
    end

    def record_audit_update
      snapshot = attributes.merge(saved_changes.transform_values { |v| v[0] }) if RailsAuditLog.store_snapshot
      record_audit_entry("update", saved_changes, snapshot)
    end

    def record_audit_destroy
      snapshot = attributes.dup if RailsAuditLog.store_snapshot
      changes = attributes.transform_values { |v| [v, nil] }
      record_audit_entry("destroy", changes, snapshot)
    end

    def record_audit_association_change(assoc_name, before, after)
      return unless RailsAuditLog.enabled?

      actor = RailsAuditLog.actor
      meta  = build_audit_metadata
      write_audit_entry(
        event:              "update",
        item_type:          self.class.name,
        item_id:            id,
        object_changes:     { assoc_name => [before, after] },
        object:             nil,
        reason:             RailsAuditLog.reason,
        metadata:           meta.presence,
        whodunnit_snapshot: actor ? RailsAuditLog.whodunnit_display.call(actor) : nil,
        actor_type:         actor&.class&.name,
        actor_id:           actor.respond_to?(:id) ? actor.id : nil
      )
    end

    def record_audit_entry(event, changes, snapshot = nil)
      return unless RailsAuditLog.enabled?

      filtered = filter_changes(changes)
      return if filtered.empty? && event == "update"

      actor = RailsAuditLog.actor
      meta  = build_audit_metadata
      write_audit_entry(
        event:               event,
        item_type:           self.class.name,
        item_id:             id,
        object_changes:      filtered,
        object:              snapshot,
        reason:              RailsAuditLog.reason,
        metadata:            meta.presence,
        whodunnit_snapshot:  actor ? RailsAuditLog.whodunnit_display.call(actor) : nil,
        actor_type:          actor&.class&.name,
        actor_id:            actor.respond_to?(:id) ? actor.id : nil
      )
    end

    def write_audit_entry(entry_attrs)
      if _audit_log_async || RailsAuditLog.async
        limit = self.class._audit_log_version_limit || RailsAuditLog.version_limit
        WriteAuditLogJob.perform_later(entry_attrs.stringify_keys, version_limit: limit)
      else
        RailsAuditLog::AuditLogEntry.create!(entry_attrs)
        prune_audit_entries
      end
    end

    def prune_audit_entries
      limit = self.class._audit_log_version_limit || RailsAuditLog.version_limit
      return unless limit

      count = audit_log_entries.count
      excess = count - limit
      return unless excess > 0

      audit_log_entries.order(id: :asc).limit(excess).delete_all
    end

    def build_audit_metadata
      meta = {}
      if self.class._audit_log_meta
        self.class._audit_log_meta.each do |key, callable|
          meta[key.to_s] = callable.arity == 0 ? callable.call : callable.call(self)
        end
      end
      meta.merge!(RailsAuditLog.request_metadata || {})
      meta
    end

    def filter_changes(changes)
      result = changes.dup

      if self.class._audit_log_only
        result.select! { |k, _| self.class._audit_log_only.include?(k) }
      else
        ignored = self.class._audit_log_ignore || RailsAuditLog.ignored_attributes
        result.reject! { |k, _| ignored.include?(k) }
      end

      result
    end
  end
end
