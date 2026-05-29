require "rails_audit_log/version"
require "rails_audit_log/engine"

module RailsAuditLog
  # Global default columns to ignore across all audited models.
  # Override in an initializer: RailsAuditLog.ignored_attributes = %w[updated_at cached_at]
  mattr_accessor :ignored_attributes, default: %w[updated_at]

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
end
