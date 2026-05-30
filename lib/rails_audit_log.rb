require "rails_audit_log/version"
require "rails_audit_log/engine"

module RailsAuditLog
  # Global default columns to ignore across all audited models.
  # Override in an initializer: RailsAuditLog.ignored_attributes = %w[updated_at cached_at]
  mattr_accessor :ignored_attributes, default: %w[updated_at]

  def self.configure
    yield self
  end
  mattr_accessor :store_snapshot, default: true
  mattr_accessor :capture_request_metadata, default: false
  mattr_accessor :version_limit, default: nil
  mattr_accessor :async, default: false
  mattr_accessor :connects_to, default: nil
  mattr_accessor :page_size,   default: 25
  mattr_accessor :whodunnit_display, default: ->(actor) {
    actor.respond_to?(:name) ? actor.name.to_s : actor.to_s
  }

  def self.request_metadata
    Thread.current[:rails_audit_log_request_metadata]
  end

  def self.request_metadata=(value)
    Thread.current[:rails_audit_log_request_metadata] = value
  end

  def self.actor
    Thread.current[:rails_audit_log_actor]
  end

  def self.actor=(actor)
    Thread.current[:rails_audit_log_actor] = actor
  end

  def self.with_actor(actor)
    previous = self.actor
    self.actor = actor
    yield
  ensure
    self.actor = previous
  end

  def self.enabled?
    !Thread.current[:rails_audit_log_disabled]
  end

  def self.disable
    previous = Thread.current[:rails_audit_log_disabled]
    Thread.current[:rails_audit_log_disabled] = true
    yield
  ensure
    Thread.current[:rails_audit_log_disabled] = previous
  end

  def self.reason
    Thread.current[:rails_audit_log_reason]
  end

  def self.reason=(value)
    Thread.current[:rails_audit_log_reason] = value
  end

  def self.audit_log_reason(value)
    previous = self.reason
    self.reason = value
    yield
  ensure
    self.reason = previous
  end

  def self.batch_audit
    return yield if Thread.current[:rails_audit_log_batch]

    Thread.current[:rails_audit_log_batch] = []
    begin
      result = yield
      batch = Thread.current[:rails_audit_log_batch]
      AuditLogEntry.insert_all!(batch) if batch.any?
      result
    ensure
      Thread.current[:rails_audit_log_batch] = nil
    end
  end

  def self.batch_audit_buffer
    Thread.current[:rails_audit_log_batch]
  end

  def self.version_at(record, time)
    entry = AuditLogEntry
      .where(item_type: record.class.name, item_id: record.id)
      .where(created_at: ..time)
      .order(created_at: :desc, id: :desc)
      .first

    return nil if entry.nil? || entry.event == "destroy"

    klass = record.class
    column_names = klass.column_names.map(&:to_s)
    to_attrs = (entry.object_changes || {})
      .select { |k, _| column_names.include?(k) }
      .transform_values { |v| v[1] }
    attrs = entry.object.present? ? entry.object.merge(to_attrs) : to_attrs

    instance = klass.new
    instance.assign_attributes(attrs.except("id"))
    instance.id = attrs.fetch("id") { entry.item_id }
    instance
  end
end
