require "rails_audit_log/version"
require "rails_audit_log/engine"
require "rails_audit_log/streaming/notifications_adapter"
require "rails_audit_log/streaming/active_job_adapter"

# RailsAuditLog is a Rails engine that tracks ActiveRecord +create+, +update+,
# and +destroy+ events as {AuditLogEntry} records with JSON-first storage and
# thread-local actor context.
#
# == Quick start
#
#   # config/initializers/rails_audit_log.rb
#   RailsAuditLog.configure do |config|
#     config.ignored_attributes = %w[updated_at cached_at]
#     config.store_snapshot      = true
#     config.async               = false
#   end
#
#   # app/models/article.rb
#   class Article < ApplicationRecord
#     include RailsAuditLog::Auditable
#     audit_log only: %i[title body]
#   end
#
#   # app/controllers/application_controller.rb
#   class ApplicationController < ActionController::Base
#     include RailsAuditLog::Controller
#     audit_log_actor { current_user }
#   end
module RailsAuditLog
  # Columns ignored on every audited model unless overridden with +only:+ or
  # +ignore:+ on {Auditable.audit_log}.
  #
  # @return [Array<String>]
  mattr_accessor :ignored_attributes, default: %w[updated_at]

  # Whether to store a full snapshot of the record's attributes in the +object+
  # column alongside +object_changes+. Disable to reduce storage at the cost of
  # losing {AuditLogEntry#reify} fidelity for pre-snapshot entries.
  #
  # @return [Boolean]
  mattr_accessor :store_snapshot, default: true

  # When +true+, captures +remote_ip+ and +user_agent+ from the current request
  # and merges them into every entry's +metadata+ column.
  # Requires {Controller} to be included in your base controller.
  #
  # @return [Boolean]
  mattr_accessor :capture_request_metadata, default: false

  # Global cap on the number of {AuditLogEntry} records kept per tracked object.
  # Oldest entries are pruned after each write once the limit is exceeded.
  # Override per-model with <tt>audit_log version_limit: N</tt>.
  #
  # @return [Integer, nil]
  mattr_accessor :version_limit, default: nil

  # Global time-based TTL for audit entries. Entries whose +created_at+ is
  # older than this duration are pruned automatically after each write.
  # Composes with {.version_limit} — an entry is removed when it exceeds
  # either constraint.
  #
  # @return [ActiveSupport::Duration, nil]
  # @example
  #   RailsAuditLog.retention_period = 90.days
  mattr_accessor :retention_period, default: nil

  # When +true+, all audit writes are dispatched via +WriteAuditLogJob+ instead
  # of being written inline. Override per-model with <tt>audit_log async: true</tt>.
  #
  # @return [Boolean]
  mattr_accessor :async, default: false

  # When +true+, encrypts +object_changes+ and +object+ for all audited models
  # using +ActiveRecord::Encryption+. Requires the host app to configure
  # +config.active_record.encryption+. Override per-model with
  # <tt>audit_log encrypt: false</tt> to opt a specific model out.
  #
  # @return [Boolean]
  mattr_accessor :encrypt, default: false

  # Passes +connects_to+ options directly to {AuditLogEntry} so audit entries
  # can be stored on a separate database.
  #
  # @return [Hash, nil]
  # @example
  #   RailsAuditLog.connects_to = { database: { writing: :audit_primary } }
  mattr_accessor :connects_to, default: nil

  # Number of entries per page in the web dashboard.
  #
  # @return [Integer]
  mattr_accessor :page_size, default: 25

  # The active streaming adapter. Any object implementing +#publish(entry)+.
  # Called after every audit entry is persisted, including batch writes.
  # Set to +nil+ (default) to disable streaming.
  #
  # @return [#publish, nil]
  # @example
  #   RailsAuditLog.streaming_adapter = RailsAuditLog::Streaming::NotificationsAdapter.new
  mattr_accessor :streaming_adapter, default: nil

  # Controls how an actor object is serialised into the +whodunnit_snapshot+
  # string column. Defaults to +actor.name+ when available, otherwise +to_s+.
  #
  # @return [Proc]
  # @example Store email instead of name
  #   RailsAuditLog.whodunnit_display = ->(actor) { actor.email }
  mattr_accessor :whodunnit_display, default: ->(actor) {
    actor.respond_to?(:name) ? actor.name.to_s : actor.to_s
  }

  # Yields the module so every +mattr_accessor+ setter is reachable as
  # <tt>config.setting = value</tt>.
  #
  # @yield [RailsAuditLog] the module itself
  # @return [void]
  # @example
  #   RailsAuditLog.configure do |config|
  #     config.ignored_attributes = %w[updated_at]
  #     config.async = true
  #   end
  def self.configure
    yield self
  end

  # Sets or returns the global tenant resolver block. The block is called at
  # write time and its return value is stored in the +tenant_id+ column of each
  # {AuditLogEntry}. Override per-model with <tt>audit_log tenant: -> { ... }</tt>.
  #
  # @yield block called with no arguments at write time; return the tenant id
  # @return [Proc, nil] the stored block, or +nil+ when not configured
  # @example
  #   RailsAuditLog.current_tenant { Current.tenant_id }
  def self.current_tenant(&block)
    @current_tenant = block if block_given?
    @current_tenant
  end

  # Wires {.current_tenant} to +ActsAsTenant.current_tenant&.id+ so audit
  # entries are automatically scoped to the Acts As Tenant context.
  # Call once in an initializer after the gem is loaded.
  #
  # @raise [RuntimeError] if the +acts_as_tenant+ gem is not loaded
  # @return [void]
  # @example
  #   RailsAuditLog.acts_as_tenant!
  def self.acts_as_tenant!
    unless defined?(ActsAsTenant)
      raise "ActsAsTenant is not loaded. Add the `acts_as_tenant` gem to your Gemfile."
    end

    current_tenant { ActsAsTenant.current_tenant&.id }
  end

  # Passes +entry+ to the configured {.streaming_adapter} if one is set.
  # No-ops when no adapter is configured.
  #
  # @api private
  # @param entry [AuditLogEntry]
  # @return [void]
  def self.publish_entry(entry)
    streaming_adapter&.publish(entry)
  end

  # Sets or returns the authentication block used to gate the web dashboard.
  # The block is evaluated in controller context, so controller helpers
  # (e.g. +current_user+) are available directly.
  # When the block returns falsy, the engine falls back to HTTP Basic auth.
  #
  # @yield block evaluated in controller context; return truthy to allow access
  # @return [Proc, nil] the stored block, or +nil+ when not configured
  # @example Require admin access
  #   RailsAuditLog.authenticate { current_user&.admin? }
  def self.authenticate(&block)
    @authenticate = block if block_given?
    @authenticate
  end

  # Returns the request metadata hash attached to the current thread.
  # Populated by {Controller} when {.capture_request_metadata} is +true+.
  #
  # @return [Hash, nil]
  def self.request_metadata
    Thread.current[:rails_audit_log_request_metadata]
  end

  # @param value [Hash, nil] metadata hash to store on the current thread
  # @return [Hash, nil]
  def self.request_metadata=(value)
    Thread.current[:rails_audit_log_request_metadata] = value
  end

  # Returns the actor set on the current thread (e.g. the signed-in user).
  #
  # @return [Object, nil]
  def self.actor
    Thread.current[:rails_audit_log_actor]
  end

  # Sets the actor on the current thread. Prefer {.with_actor} for scoped
  # assignment so the value is always restored.
  #
  # @param actor [Object, nil]
  # @return [Object, nil]
  def self.actor=(actor)
    Thread.current[:rails_audit_log_actor] = actor
  end

  # Sets the actor for the duration of the block, then restores the previous
  # value. Use this in background jobs and rake tasks.
  #
  # @param actor [Object] the actor to set (e.g. a +User+ record)
  # @yield executes the block with +actor+ as the current actor
  # @return [Object] the return value of the block
  # @example
  #   RailsAuditLog.with_actor(robot_user) { DataImporter.new.run }
  def self.with_actor(actor)
    previous = self.actor
    self.actor = actor
    yield
  ensure
    self.actor = previous
  end

  # Returns +true+ when audit logging is active on the current thread.
  #
  # @return [Boolean]
  def self.enabled?
    !Thread.current[:rails_audit_log_disabled]
  end

  # Suspends audit logging for the duration of the block on the current thread.
  # Useful in seeds, factories, and test setup where audit noise is unwanted.
  #
  # @yield executes the block with audit logging disabled
  # @return [Object] the return value of the block
  # @example
  #   RailsAuditLog.disable { Post.create!(title: "seed post") }
  def self.disable
    previous = Thread.current[:rails_audit_log_disabled]
    Thread.current[:rails_audit_log_disabled] = true
    yield
  ensure
    Thread.current[:rails_audit_log_disabled] = previous
  end

  # Returns the reason string set on the current thread.
  #
  # @return [String, nil]
  def self.reason
    Thread.current[:rails_audit_log_reason]
  end

  # @param value [String, nil]
  # @return [String, nil]
  def self.reason=(value)
    Thread.current[:rails_audit_log_reason] = value
  end

  # Sets a human-readable reason for the changes made within the block.
  # The reason is stored in each {AuditLogEntry#reason} and restored afterwards.
  #
  # @param value [String] reason to attach to every entry written in the block
  # @yield executes the block with +value+ as the current reason
  # @return [Object] the return value of the block
  # @example
  #   RailsAuditLog.audit_log_reason("bulk import") { records.each(&:save!) }
  def self.audit_log_reason(value)
    previous = self.reason
    self.reason = value
    yield
  ensure
    self.reason = previous
  end

  # Collects all {AuditLogEntry} records created within the block and inserts
  # them with a single <tt>INSERT ... VALUES (…), (…)</tt> via +insert_all!+
  # instead of one INSERT per record.
  #
  # Calls are idempotent: if a batch is already in progress on the current
  # thread (i.e. a nested call), the inner block joins the outer batch.
  #
  # @yield executes the block; any audit entries created are buffered
  # @return [Object] the return value of the block
  # @raise [ActiveRecord::RecordInvalid] if any entry fails the +insert_all!+
  # @example
  #   RailsAuditLog.batch_audit { 500.times { |i| Post.create!(title: "Post #{i}") } }
  def self.batch_audit
    return yield if Thread.current[:rails_audit_log_batch]

    Thread.current[:rails_audit_log_batch] = []
    begin
      result = yield
      batch = Thread.current[:rails_audit_log_batch]
      if batch.any?
        AuditLogEntry.insert_all!(batch)
        batch.each { |attrs| publish_entry(AuditLogEntry.new(attrs)) } if streaming_adapter
      end
      result
    ensure
      Thread.current[:rails_audit_log_batch] = nil
    end
  end

  # Returns the in-progress batch buffer for the current thread, or +nil+ when
  # no batch is active.
  #
  # @api private
  # @return [Array<Hash>, nil]
  def self.batch_audit_buffer
    Thread.current[:rails_audit_log_batch]
  end

  # Reconstructs the state of +record+ as it was at +time+ by replaying audit
  # entries up to that timestamp.
  #
  # Returns an unsaved, non-persisted instance of +record.class+ whose
  # attributes match the record's state at +time+, or +nil+ when no audit
  # entry exists before +time+ or the record was destroyed at or before +time+.
  #
  # @param record [ActiveRecord::Base] the record to reconstruct
  # @param time [Time] the point in time to reconstruct at
  # @return [ActiveRecord::Base, nil] a new, unpersisted instance; or +nil+
  # @example
  #   post = Post.find(42)
  #   snapshot = RailsAuditLog.version_at(post, 1.week.ago)
  #   snapshot.title  # => title as it was a week ago
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
