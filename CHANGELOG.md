# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `audit_log only: [:attr]` — track only the listed attributes on a model
- `audit_log ignore: [:attr]` — exclude listed attributes from tracking on a model
- `RailsAuditLog.ignored_attributes` — global default ignored columns (default: `["updated_at"]`); configure in an initializer
- Updates that result in no tracked changes after filtering are silently skipped
- `RailsAuditLog.disable { }` — suppresses all audit writes inside the block (thread-safe)
- `RailsAuditLog.enabled?` — returns whether auditing is currently active on this thread
- `record.skip_audit_log { }` — instance-level helper that delegates to `RailsAuditLog.disable`

## [0.2.0] - 2026-05-29

### Added

- `.created_events`, `.updated_events`, `.destroyed_events` scopes on `AuditLogEntry`
- `.by_actor(actor)` scope — filter entries by polymorphic actor
- `.for_resource(record_or_class)` scope — filter by a specific record or all entries for a class
- `.since(time)` / `.until(time)` scopes — time-bounded queries
- `.touching(attribute)` scope — entries where `object_changes` includes the given attribute
- `AuditLogEntry#changed_attributes` — returns the list of attribute names that changed
- `AuditLogEntry#diff` — returns `{ "attr" => { from:, to: } }` hash for any event
- `AuditLogEntry#actor` — polymorphic association to the whodunnit record

## [0.1.0] - 2026-05-29

### Added

- `RailsAuditLog::AuditLogEntry` model backed by an `audit_log_entries` table with `event`, `item_type`, `item_id`, `object_changes` (JSON), `actor_type`, `actor_id`, and `created_at` columns
- Polymorphic `belongs_to :item` (required) and `belongs_to :actor` (optional) associations
- `.creates`, `.updates`, and `.destroys` scopes
- Install generator: `bin/rails generate rails_audit_log:install` creates the `audit_log_entries` migration
- `RailsAuditLog::Auditable` concern — include in any ActiveRecord model to track `create`, `update`, and `destroy` events automatically
- `model_instance.audit_log_entries` polymorphic `has_many` association
- `RailsAuditLog.actor` / `RailsAuditLog.actor=` / `RailsAuditLog.with_actor` thread-local actor context
- `RailsAuditLog::Controller` concern — include in any controller and call `audit_log_actor { current_user }` to automatically wire the actor for every request
- Engine properly isolated under `RailsAuditLog` namespace; `Auditable` and `Controller` are Zeitwerk-autoloaded from `app/concerns/` — no manual `require` needed

[Unreleased]: https://github.com/eclectic-coding/rails_audit_log/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.2.0
[0.1.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.1.0
