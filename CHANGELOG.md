# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `audit_log version_limit: N` — caps the number of `AuditLogEntry` records retained per tracked object; oldest entries are pruned automatically after each write once the limit is exceeded
- `RailsAuditLog.version_limit = N` — global default applied when no per-model limit is set; per-model `version_limit:` takes precedence
- `audit_log async: true` — enqueues audit writes via `RailsAuditLog::WriteAuditLogJob` (an `ActiveJob::Base` subclass) instead of writing inline; entry creation and version pruning both happen inside the job
- `RailsAuditLog.async = true` — global default that enables async writes for all audited models; per-model `async: true` takes precedence over the default
- `RailsAuditLog.batch_audit { }` — buffers all audit writes inside the block and flushes them with a single `insert_all!` call at the end, eliminating N+1 inserts during bulk imports; nested calls accumulate into the outermost batch; if the block raises, the buffer is discarded and no entries are written
- `AuditLogEntry.slim` scope — selects all columns except the three JSON blob columns (`object_changes`, `object`, `metadata`); use for index or listing queries where blob data is not needed to reduce I/O and memory usage

## [0.6.0] - 2026-05-29

### Added

- `audit_log associations: true` — automatically records `has_many` add/remove events as `update` entries on the parent model; `object_changes` stores `{ "association_name" => [nil, { "id" => X, "type" => "ClassName" }] }` for adds and `[{ "id" => X, "type" => "ClassName" }, nil]` for removes
- `audit_log associations: [:tags, :comments]` — restrict association tracking to a named subset; associations not in the list are unaffected
- `has_many` with `after_add`/`after_remove` callbacks from other gems are preserved when association tracking is enabled; existing callbacks are merged rather than replaced
- `has_many :through` join-table association changes are tracked automatically via the same `audit_log associations:` option — no extra configuration required
- `has_and_belongs_to_many` add/remove events are tracked; `object_changes` uses the same `[nil, {"id" => X, "type" => "ClassName"}]` / `[{...}, nil]` format as direct `has_many`

### Fixed

- `AuditLogEntry#reify` no longer raises `ActiveRecord::AssociationTypeMismatch` when called on an association-change entry; non-column keys in `object_changes` (e.g. `"tags"`, `"comments"`) are now filtered out before attributes are assigned to the reconstructed instance
- `RailsAuditLog.version_at` applies the same column-name filter so it does not raise when the nearest audit entry before the requested time is an association-change entry

## [0.5.0] - 2026-05-29

### Added

- `audit_log meta: { key: -> { value } }` — attach computed metadata to every entry for a model; lambdas are evaluated at write time; zero-arg lambdas (`-> { Current.tenant.id }`) and one-arg lambdas (`->(record) { record.title }`) are both supported; merged with request metadata when both are active
- Request metadata capture — when `RailsAuditLog.capture_request_metadata = true`, the `Controller` concern automatically stores `remote_ip` and `user_agent` from the current request into the entry's `metadata` column on every audited write
- `AuditLogEntry#whodunnit_snapshot` — stores the actor's display name at write time; survives actor deletion; defaults to `actor.name` if available, otherwise `actor.to_s`
- `RailsAuditLog.whodunnit_display` — configurable proc for deriving the snapshot value (e.g. `RailsAuditLog.whodunnit_display = ->(actor) { actor.email }`)
- `AuditLogEntry#reason` — nullable string column for a free-text rationale attached at write time
- `RailsAuditLog.audit_log_reason(value) { }` — thread-local helper that sets `reason` on all entries created inside the block; restores the previous value (or nil) on exit, even if the block raises
- `AuditLogEntry#metadata` — nullable JSON column for arbitrary key/value storage; validated to be a Hash when present

## [0.4.0] - 2026-05-29

### Added

- PostgreSQL CI job — tests the full suite against Postgres 16 (Ruby 4.0, all supported Rails versions) via `DATABASE_URL`; `pg` gem added to a `db_postgres` Bundler group so contributors without libpq can opt out with `bundle config set --local without db_postgres`

### Changed

- `.touching` scope uses `object_changes->>? IS NOT NULL` for PostgreSQL (works with `json` columns; the previous `?` operator required `jsonb`)
- Existing SQLite test job renamed to clarify it runs SQLite only

### Added

- `RailsAuditLog.version_at(record, time)` — returns an unsaved AR instance reflecting the record's state at an arbitrary timestamp; finds the last audit entry at or before `time`, applies the post-change attribute values, and returns `nil` if no history exists or the record was destroyed at or before `time`
- `AuditLogEntry#previous` / `#next` — navigate the version chain for a given record; returns the adjacent entry (by `id`) scoped to the same `item_type` and `item_id`, or `nil` at either end
- `AuditLogEntry#reify` — returns an unsaved ActiveRecord instance reflecting the record's state before the audit entry was created; returns `nil` for `create` events, restores pre-change attribute values for `update` events (merged with the current record's unchanged attributes), and reconstructs the pre-delete state for `destroy` events
- `object` JSON column on `audit_log_entries` — stores the full pre-change attribute snapshot alongside `object_changes`; `reify` uses it directly when present, avoiding a database lookup
- `RailsAuditLog.store_snapshot` config option (default: `true`) — set to `false` for diff-only mode to reduce storage; `reify` falls back to reconstructing state from `object_changes` when the snapshot is absent

## [0.3.0] - 2026-05-29

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

[Unreleased]: https://github.com/eclectic-coding/rails_audit_log/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.6.0
[0.5.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.5.0
[0.4.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.4.0
[0.3.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.3.0
[0.2.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.2.0
[0.1.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.1.0
