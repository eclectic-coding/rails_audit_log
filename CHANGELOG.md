# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-06-02

### Added

- `RailsAuditLog.current_tenant { Current.tenant_id }` — global tenant resolver; the block is called at write time and its return value is stored in a new `tenant_id` string column on `audit_log_entries`; used when no per-model override is set
- `audit_log tenant: -> { Current.tenant_id }` — per-model tenant lambda evaluated at write time; takes precedence over the global `current_tenant` resolver; stored in the `tenant_id` column of each entry
- `bin/rails generate rails_audit_log:tenant` — migration generator that adds the `tenant_id` string column and index to `audit_log_entries`
- `AuditLogEntry.for_tenant(id)` scope — filters all queries by `tenant_id`; composable with all existing scopes
- Dashboard (`/audit`) automatically scopes all entries to the current tenant when `RailsAuditLog.current_tenant` is configured; applies to the entries index and per-resource timeline
- `RailsAuditLog.acts_as_tenant!` — one-line integration with the `acts_as_tenant` gem; wires `current_tenant` to `ActsAsTenant.current_tenant&.id`

## [1.2.0] - 2026-06-01

### Added

- `config.encrypt` option added to the `rails_audit_log:initializer` template so `RailsAuditLog.encrypt = true` is documented alongside all other configuration options
- `bin/rails generate rails_audit_log:encryption` — generator that creates an `ActiveRecord::Encryption` config initializer (referencing `bin/rails db:encryption:init`) and a data migration that re-encrypts existing plain-text audit entries for models using `audit_log encrypt: true`; the migration skips already-encrypted entries so it is safe to re-run; irreversible
- `RailsAuditLog.encrypt = true` — global encryption default; all audited models encrypt `object_changes` and `object` at write time using `ActiveRecord::Encryption`; per-model `audit_log encrypt: false` opts a specific model out; per-model `audit_log encrypt: true` opts a model in even when the global default is off
- `audit_log encrypt: true` — opt-in per-model encryption of the `object_changes` and `object` columns using `ActiveRecord::Encryption` (Rails 7.1+); requires `config.active_record.encryption` to be configured in the host app; decryption is transparent — `#diff`, `#reify`, `#changed_attributes`, and all instance methods work unchanged; the `touching` scope uses SQL JSON extraction and will not match encrypted entries
- `CONTRIBUTING.md` — contributor guide covering dev setup, test commands, branch and CHANGELOG conventions, RuboCop, bug reporting, and PR submission steps; README Contributing section updated to link to it

## [1.1.0] - 2026-05-31

### Added

- `RailsAuditLog.retention_period = 90.days` — global time-based TTL; entries whose `created_at` is older than the configured duration are pruned automatically after each write; composes with `version_limit` — an entry is removed when it exceeds either constraint; `async` mode passes the period to `WriteAuditLogJob` so pruning happens inside the job
- `audit_log retain_for: 30.days` — per-model time-based TTL; takes precedence over the global `retention_period`; stored as `_audit_log_retain_for` class attribute; composes with `version_limit`
- `RailsAuditLog::PruneAuditLogJob` — `ActiveJob::Base` subclass that prunes all audited models in one pass; iterates over every `item_type` in `audit_log_entries`, resolves the effective `retain_for` / `retention_period` and `version_limit` per model, and deletes entries that exceed either constraint; enqueue on a schedule via Solid Queue, Sidekiq, or any ActiveJob adapter
- `bin/rails rails_audit_log:prune` — rake task for manual or cron-driven pruning; delegates to `PruneAuditLogJob.perform_now`

## [1.0.0] - 2026-05-31

### Added

- CHANGELOG audited for completeness across the full 0.x series; added missing `AuditLogEntry.for_period` entry (0.9.0) and deprecation notice for `.creates`/`.updates`/`.destroys` short aliases (0.2.0)
- Full YARD API documentation for every public class, module, method, configuration option, and scope; covers `RailsAuditLog` module methods, `Auditable`, `Controller`, `AuditLogEntry`, `Matchers`, `MinitestAssertions`, `TestHelpers`, and `PaperTrailCompat`; internal methods annotated `@api private`
- Performance benchmark suite (`benchmarks/suite.rb`) covering write throughput, `batch_audit` vs individual writes, query performance, storage per entry; each section compares directly against PaperTrail side-by-side using `benchmark-ips`; run with `bundle exec rake benchmark`; results documented in `BENCHMARKS.md`
- `RailsAuditLog::PaperTrailCompat` — opt-in concern for gradual migration from PaperTrail; adds `versions` association (oldest-first alias for `audit_log_entries`) and a `paper_trail` proxy exposing `#version`, `#previous_version`, `#originator`, and `#version_at(time)`
- `bin/rails generate rails_audit_log:migrate_from_paper_trail` — data migration generator that copies PaperTrail `versions` rows to `audit_log_entries`; handles both YAML and JSON serialization; maps `whodunnit` to `whodunnit_snapshot`; processes in batches of 1 000; skips non-standard events; irreversible
- Stable public API documented in README with full surface inventory (module methods, concerns, scopes, instance methods, testing helpers, generators) and semver guarantee; internal classes annotated `@api private` (Engine, dashboard controllers, ApplicationRecord, ApplicationJob, ApplicationHelper)

## [0.9.0] - 2026-05-30

### Added

- `RailsAuditLog.authenticate { current_user&.admin? }` — configurable authentication block for the web dashboard; block runs in controller context so controller helpers are available directly; `{ |c| c.current_user&.admin? }` style also supported; falls back to HTTP Basic auth when the block returns falsy; leave unset to allow unauthenticated access
- Diff display toggle — inline (attribute/before/after table) and side-by-side (two-panel grid) modes; preference persists in `localStorage`; powered by a Stimulus `DiffController`; inline is the no-JS default
- Dashboard filter bar — event type (create/update/destroy), resource class, actor name search, and time period (1h/24h/7d/All); filters are inside the Turbo Frame so they update results without a full-page reload; URL updates via `turbo_action: "advance"` so browser history and direct links work; Clear link resets all active filters; auto-submits on select change and debounces text input via a Stimulus `SearchController`
- Per-resource timeline at `/audit/audit_log_entries/resource/:item_type/:item_id` — all entries for one record in chronological order, each showing event badge, actor, timestamp, optional reason, and inline diff; Turbo Frame pagination
- Single-entry show page — breadcrumb nav, metadata card (event, resource, actor, timestamp, reason), full diff table, and Previous/Next entry navigation following the version chain
- Shared diff partial — before/after table for `object_changes`; nil rendered as "—", associations shown as "Type #id", scalars in monospace with red/green colouring
- Dashboard index view at `/audit` — paginated table of all audit entries (newest first) using pagy; table shows event badge, resource link, actor display name, and timestamp; Turbo Frame wraps the table so page navigation is a partial update without a full-page reload; includes empty state
- `RailsAuditLog.page_size = N` — configures entries per page in the web dashboard (default 25); set in an initializer or the `configure` block
- Mountable web dashboard at a configurable path via `mount RailsAuditLog::Engine, at: "/audit"`; engine routes define a root and `audit_log_entries` index and show endpoints
- Asset delivery via propshaft, importmaps, and CDN-pinned `@hotwired/turbo` and `@hotwired/stimulus`; no inline style injection, no host app asset pipeline conflict
- `turbo-rails` and `importmap-rails` added as gem dependencies
- `AuditLogEntry.for_period(period)` scope — filters to entries within a named window; accepts `"1h"` (last hour), `"24h"` (last 24 hours), or `"7d"` (last 7 days); used by the dashboard filter bar and available for application queries

## [0.8.0] - 2026-05-30

### Added

- Boot-time warning when a model includes `RailsAuditLog::Auditable` but the `audit_log_entries` table does not exist; the message names the model and provides the exact command to run the install generator and migration; silently skipped when the database is not yet reachable (e.g. before `db:create`)
- `bin/rails generate rails_audit_log:initializer` — generates `config/initializers/rails_audit_log.rb` with every configuration option documented as commented examples inside a `RailsAuditLog.configure` block
- `RailsAuditLog.configure { |config| }` — optional block-style configuration; yields the module so all `mattr_accessor` setters are reachable as `config.setting = value`
- `RailsAuditLog::MinitestAssertions` — opt-in Minitest assertions; `require "rails_audit_log/minitest_assertions"` and `include RailsAuditLog::MinitestAssertions` in `ActiveSupport::TestCase` to get `assert_audit_log_entry(record, event:, touching:, message:)` and `refute_audit_log_entry(record, event:, touching:, message:)`
- `RailsAuditLog::TestHelpers` — opt-in test helper module; `require "rails_audit_log/test_helpers"` and `include RailsAuditLog::TestHelpers` to get `without_audit_log { }`, a prefix-free wrapper around `RailsAuditLog.disable` for use in FactoryBot factories, seeds, and other test setup
- `RailsAuditLog::Matchers` — opt-in RSpec matchers; add `require "rails_audit_log/matchers"` and `include RailsAuditLog::Matchers` to use:
  - `expect(record).to have_audit_log_entry(:update).touching(:title)` — asserts the record has a matching audit entry
  - `expect { action }.to create_audit_log_entry(event: :create, touching: :title)` — asserts the block produces a matching entry; supports chaining `.touching`

## [0.7.0] - 2026-05-30

### Added

- `audit_log version_limit: N` — caps the number of `AuditLogEntry` records retained per tracked object; oldest entries are pruned automatically after each write once the limit is exceeded
- `RailsAuditLog.version_limit = N` — global default applied when no per-model limit is set; per-model `version_limit:` takes precedence
- `audit_log async: true` — enqueues audit writes via `RailsAuditLog::WriteAuditLogJob` (an `ActiveJob::Base` subclass) instead of writing inline; entry creation and version pruning both happen inside the job
- `RailsAuditLog.async = true` — global default that enables async writes for all audited models; per-model `async: true` takes precedence over the default
- `RailsAuditLog.batch_audit { }` — buffers all audit writes inside the block and flushes them with a single `insert_all!` call at the end, eliminating N+1 inserts during bulk imports; nested calls accumulate into the outermost batch; if the block raises, the buffer is discarded and no entries are written
- `AuditLogEntry.slim` scope — selects all columns except the three JSON blob columns (`object_changes`, `object`, `metadata`); use for index or listing queries where blob data is not needed to reduce I/O and memory usage
- `RailsAuditLog.connects_to = { database: { writing: :audit_db, reading: :audit_db } }` — optional separate database connection for `AuditLogEntry`; set in an initializer and the engine applies it via `connects_to` at boot; use to write audit data to a dedicated database without affecting the main app connection

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

### Changed

- `.creates`, `.updates`, and `.destroys` scopes are now deprecated aliases for the new `_events`-suffixed names; they remain functional for backwards compatibility but will be removed in a future major release

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

[Unreleased]: https://github.com/eclectic-coding/rails_audit_log/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v1.3.0
[1.2.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v1.2.0
[1.1.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v1.1.0
[1.0.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v1.0.0
[0.9.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.9.0
[0.8.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.8.0
[0.7.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.7.0
[0.6.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.6.0
[0.5.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.5.0
[0.4.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.4.0
[0.3.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.3.0
[0.2.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.2.0
[0.1.0]: https://github.com/eclectic-coding/rails_audit_log/releases/tag/v0.1.0
