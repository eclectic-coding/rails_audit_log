require "rails_audit_log/version"
require "rails_audit_log/engine"

module RailsAuditLog
  # Global default columns to ignore across all audited models.
  # Override in an initializer: RailsAuditLog.ignored_attributes = %w[updated_at cached_at]
  mattr_accessor :ignored_attributes, default: %w[updated_at]
  mattr_accessor :store_snapshot, default: true
  mattr_accessor :whodunnit_display, default: ->(actor) {
    actor.respond_to?(:name) ? actor.name.to_s : actor.to_s
  }

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

  def self.version_at(record, time)
    entry = AuditLogEntry
      .where(item_type: record.class.name, item_id: record.id)
      .where(created_at: ..time)
      .order(created_at: :desc, id: :desc)
      .first

    return nil if entry.nil? || entry.event == "destroy"

    klass = record.class
    to_attrs = (entry.object_changes || {}).transform_values { |v| v[1] }
    attrs = entry.object.present? ? entry.object.merge(to_attrs) : to_attrs

    instance = klass.new
    instance.assign_attributes(attrs.except("id"))
    instance.id = attrs.fetch("id") { entry.item_id }
    instance
  end
end
