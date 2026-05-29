require "rails_audit_log/version"
require "rails_audit_log/engine"
require "rails_audit_log/auditable"
require "rails_audit_log/controller"

module RailsAuditLog
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
