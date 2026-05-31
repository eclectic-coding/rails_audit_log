# RailsAuditLog

[![CI](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml/badge.svg)](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/rails_audit_log.svg)](https://rubygems.org/gems/rails_audit_log)
[![Downloads](https://img.shields.io/gem/dt/rails_audit_log.svg)](https://rubygems.org/gems/rails_audit_log)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-ruby)](https://www.ruby-lang.org)
[![codecov](https://codecov.io/gh/eclectic-coding/rails_audit_log/branch/main/graph/badge.svg)](https://codecov.io/gh/eclectic-coding/rails_audit_log)

Audit logging for Rails. Tracks `create`, `update`, and `destroy` events as structured JSON records with a mountable web dashboard, whodunnit actor context, batch writes, time-travel reconstruction, and test helpers — a clean, well-documented replacement for PaperTrail with a built-in migration path.

## Table of contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Web dashboard](#web-dashboard)
- [Usage](#usage)
  - [Tracking a model](#tracking-a-model)
  - [Recording who made the change](#recording-who-made-the-change)
  - [Actor context outside of controllers](#actor-context-outside-of-controllers)
  - [Querying the audit log](#querying-the-audit-log)
  - [Lightweight queries](#lightweight-queries)
  - [Association tracking](#association-tracking)
  - [Bulk audit writes](#bulk-audit-writes)
  - [Async audit writes](#async-audit-writes)
  - [Capping history per record](#capping-history-per-record)
  - [Time-based retention](#time-based-retention)
  - [Selective tracking](#selective-tracking)
  - [Disabling auditing](#disabling-auditing)
  - [Object reconstruction](#object-reconstruction)
  - [Attaching a reason](#attaching-a-reason)
  - [Arbitrary metadata](#arbitrary-metadata)
  - [Request metadata capture](#request-metadata-capture)
  - [Actor display name snapshot](#actor-display-name-snapshot)
  - [Object snapshot storage](#object-snapshot-storage)
  - [Separate audit database](#separate-audit-database)
  - [Test helpers](#test-helpers)
- [Stability and versioning](#stability-and-versioning)
- [Migrating from PaperTrail](#migrating-from-papertrail)
- [Performance](#performance)
- [Companion gems](#companion-gems)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [License](#license)

## Installation

[↑ Table of contents](#table-of-contents)

Add to your `Gemfile`:

```ruby
gem "rails_audit_log"
```

Run the install generator to create the migration:

```bash
bin/rails generate rails_audit_log:install
bin/rails db:migrate
```

## Configuration

[↑ Table of contents](#table-of-contents)

Run the initializer generator to create `config/initializers/rails_audit_log.rb` with every option documented as a commented example:

```bash
bin/rails generate rails_audit_log:initializer
```

The generated file (shown below with all options) uses the block-style `configure` API. Every setting has a sensible default — uncomment only what you need:

```ruby
# config/initializers/rails_audit_log.rb

RailsAuditLog.configure do |config|
  # Global columns excluded from all audited models.
  # Default: ["updated_at"]
  # config.ignored_attributes = %w[updated_at cached_at]

  # Store a full attribute snapshot alongside object_changes.
  # Default: true
  # Disable to save storage; reify and version_at fall back to diff-only reconstruction.
  # config.store_snapshot = false

  # Capture remote_ip and user_agent into each entry's metadata column.
  # Default: false — requires RailsAuditLog::Controller in ApplicationController.
  # config.capture_request_metadata = true

  # Customise how the actor's display name is stored at write time.
  # Default: actor.name if available, otherwise actor.to_s
  # config.whodunnit_display = ->(actor) { actor.email }

  # Global cap on entries retained per tracked record. nil = no limit.
  # Per-model `audit_log version_limit: N` takes precedence.
  # config.version_limit = 100

  # Global time-based TTL — entries older than this duration are pruned after
  # each write. Composes with version_limit: an entry is removed when it
  # exceeds either constraint. Default: nil (no TTL)
  # config.retention_period = 90.days

  # Write all audit entries asynchronously via WriteAuditLogJob.
  # Default: false — per-model `audit_log async: true` also works.
  # config.async = true

  # Route AuditLogEntry to a dedicated database (Rails multi-DB).
  # config.connects_to = { database: { writing: :audit_log, reading: :audit_log } }

  # Entries per page in the web dashboard. Default: 25
  # config.page_size = 50

  # Gate web dashboard access. Block runs in controller context so controller
  # helpers like current_user are available directly. Falls back to HTTP Basic
  # auth when the block returns falsy. Leave unset for unauthenticated access.
  # config.authenticate { current_user&.admin? }
  # config.authenticate { |c| c.current_user&.admin? }
end
```

Each option is documented in detail in its own Usage section below.

## Web dashboard

[↑ Table of contents](#table-of-contents)

Mount the engine in `config/routes.rb` to enable the built-in audit trail browser:

```ruby
mount RailsAuditLog::Engine, at: "/audit"
```

Then visit `/audit` to browse all audit entries. The dashboard is delivered via propshaft, importmaps, and CDN-pinned Turbo and Stimulus — no asset pipeline configuration required in the host app.

## Usage

[↑ Table of contents](#table-of-contents)

### Tracking a model

Include `RailsAuditLog::Auditable` in any ActiveRecord model:

```ruby
class Article < ApplicationRecord
  include RailsAuditLog::Auditable
end
```

Every `create`, `update`, and `destroy` is now recorded automatically:

```ruby
article = Article.create!(title: "Hello")
article.audit_log_entries.count       # => 1
article.audit_log_entries.first.event # => "create"

article.update!(title: "World")
article.audit_log_entries.last.object_changes
# => { "title" => ["Hello", "World"] }
```

### Recording who made the change

Include `RailsAuditLog::Controller` in your `ApplicationController` and declare the actor source once:

```ruby
class ApplicationController < ActionController::Base
  include RailsAuditLog::Controller
  audit_log_actor { current_user }
end
```

The actor is captured automatically on every request and stored on each entry:

```ruby
entry = article.audit_log_entries.last
entry.actor       # => #<User id: 42, name: "Alice">
entry.actor_type  # => "User"
entry.actor_id    # => 42
```

### Actor context outside of controllers

Use `RailsAuditLog.with_actor` in background jobs, rake tasks, or seeds:

```ruby
RailsAuditLog.with_actor(current_user) do
  article.update!(status: "published")
end
```

### Querying the audit log

```ruby
# Event scopes
article.audit_log_entries.created_events
article.audit_log_entries.updated_events
article.audit_log_entries.destroyed_events

# Filter by actor, resource, or time
RailsAuditLog::AuditLogEntry.by_actor(current_user)
RailsAuditLog::AuditLogEntry.for_resource(Article)
RailsAuditLog::AuditLogEntry.for_resource(article)
RailsAuditLog::AuditLogEntry.since(1.week.ago)
RailsAuditLog::AuditLogEntry.until(Date.yesterday)

# Find entries that touched a specific attribute
RailsAuditLog::AuditLogEntry.touching(:title)

# Inspect what changed
entry = article.audit_log_entries.last
entry.changed_attributes  # => ["title"]
entry.diff
# => { "title" => { from: "Hello", to: "World" } }
```

### Lightweight queries

Use `.slim` to exclude the three JSON blob columns (`object_changes`, `object`, `metadata`) from the SQL projection. This is useful for index or listing views where you only need the entry header (who, what event, when):

```ruby
entries = AuditLogEntry.slim.for_resource(article).since(1.week.ago)
entries.first.event          # => "update"
entries.first.actor_type     # => "User"
entries.first.object_changes # => raises ActiveModel::MissingAttributeError
```

> **Note:** Use `.count(:id)` instead of `.count` when chaining `.slim` with other scopes — Rails' `COUNT` with a multi-column `SELECT` is not supported by all databases.

### Association tracking

Track `has_many` add and remove events by passing `associations: true` to `audit_log`. Call `audit_log` **before** the `has_many` declarations so the callbacks are wired at class load time:

```ruby
class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log associations: true
  has_many :tags
  has_many :comments, dependent: :destroy
end
```

Each add or remove creates an `update` entry on the parent with the associated record's identity in `object_changes`:

```ruby
post = Post.create!(title: "Hello")
tag  = post.tags.create!(name: "Ruby")

entry = post.audit_log_entries.updated_events.last
entry.object_changes
# => { "tags" => [nil, { "id" => 1, "type" => "Tag" }] }

post.tags.delete(tag)
entry = post.audit_log_entries.updated_events.last
entry.object_changes
# => { "tags" => [{ "id" => 1, "type" => "Tag" }, nil] }
```

Track only a named subset of associations:

```ruby
audit_log associations: [:tags]  # comments changes are not recorded
```

`has_many :through` and `has_and_belongs_to_many` work the same way — no extra configuration:

```ruby
class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log associations: true
  has_many :taggings
  has_many :tags, through: :taggings   # tracked automatically
  has_and_belongs_to_many :categories  # tracked automatically
end
```

`belongs_to` foreign-key changes are already tracked as regular column updates and require no extra configuration.

### Bulk audit writes

Wrap a block with `RailsAuditLog.batch_audit` to buffer all audit entries and flush them in a single `insert_all!` call at the end, eliminating N+1 inserts during imports:

```ruby
RailsAuditLog.batch_audit do
  records.each { |attrs| Post.create!(attrs) }
end
# All audit entries written in one INSERT
```

Nested calls accumulate into the outermost batch — only one `insert_all!` fires. If the block raises, the buffer is discarded and no entries are written.

> **Note:** Version pruning (`version_limit`) is deferred in batch mode — the next write outside the batch will trigger pruning as usual.

### Async audit writes

Offload audit writes to a background job by passing `async: true` to `audit_log`. The entry is enqueued via `RailsAuditLog::WriteAuditLogJob` (a subclass of `ActiveJob::Base`) so the request does not block on the database write:

```ruby
class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log async: true
end
```

Enable async globally in an initializer — per-model `async: true` takes precedence:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.async = true
```

Configure the queue adapter and queue name through standard ActiveJob settings. Version pruning also runs inside the job when `version_limit` is set.

### Capping history per record

Limit how many audit entries are kept per record with `version_limit:`. Oldest entries are pruned automatically after each write once the cap is reached:

```ruby
class Post < ApplicationRecord
  include RailsAuditLog::Auditable
  audit_log version_limit: 10  # keep only the 10 most recent entries
end
```

Set a global default in an initializer — per-model values take precedence:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.version_limit = 50
```

### Time-based retention

Automatically prune entries older than a configured duration by setting `retention_period` in an initializer:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.retention_period = 90.days
```

Entries whose `created_at` is older than the period are deleted after each write. `retention_period` and `version_limit` compose — an entry is pruned when it exceeds **either** constraint.

### Selective tracking

Track only specific attributes, or exclude noisy ones:

```ruby
class Article < ApplicationRecord
  include RailsAuditLog::Auditable

  # Track only these columns
  audit_log only: [:title, :status]

  # Or exclude specific columns
  audit_log ignore: [:cached_at, :views_count]
end
```

Configure global defaults in an initializer:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.ignored_attributes = %w[updated_at cached_at]
```

Updates that produce no tracked changes after filtering are silently skipped.

### Disabling auditing

Suppress all audit writes inside a block — thread-safe, works in jobs and imports:

```ruby
RailsAuditLog.disable do
  Article.insert_all!(bulk_rows)
end

RailsAuditLog.enabled? # => true (restored after the block)
```

Disable on a specific record instance:

```ruby
article.skip_audit_log { article.update!(cached_at: Time.current) }
```

### Object reconstruction

**Reify a single entry** — `AuditLogEntry#reify` returns an unsaved ActiveRecord instance reflecting the record's state **before** the entry was recorded:

```ruby
article.update!(title: "v2")
entry = article.audit_log_entries.updated_events.last

previous = entry.reify
previous.title      # => "v1"  (the pre-update state)
previous.persisted? # => false
```

Returns `nil` for `create` entries (nothing existed before).

**Reconstruct state at any point in time:**

```ruby
snapshot = RailsAuditLog.version_at(article, 1.week.ago)
snapshot.title  # => whatever the title was a week ago
```

Returns `nil` if the record had no history at that time or was already destroyed.

**Navigate the version chain:**

```ruby
entry = article.audit_log_entries.updated_events.last
entry.previous  # => the entry before this one
entry.next      # => the entry after this one (nil if last)
```

### Attaching a reason

Record a free-text rationale alongside any write using a thread-local block — safe to nest, cleared automatically:

```ruby
RailsAuditLog.audit_log_reason("Approved by legal") do
  contract.update!(status: "approved")
end

entry.reason  # => "Approved by legal"
```

### Arbitrary metadata

The `metadata` JSON column accepts any key/value hash. Populate it automatically with `audit_log meta:`:

```ruby
class Article < ApplicationRecord
  include RailsAuditLog::Auditable

  # Zero-arg lambda — evaluated at write time (good for thread-locals)
  # One-arg lambda — receives the record instance
  audit_log meta: {
    tenant_id:    -> { Current.tenant.id },
    title_length: ->(record) { record.title.length }
  }
end

entry.metadata  # => { "tenant_id" => "acme", "title_length" => 12 }
```

### Request metadata capture

Enable opt-in capture of `remote_ip` and `user_agent` from the current request in an initializer:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.capture_request_metadata = true
```

When enabled, the `Controller` concern automatically stores these into each entry's `metadata` column:

```ruby
entry.metadata  # => { "remote_ip" => "203.0.113.1", "user_agent" => "Mozilla/5.0 ..." }
```

Request metadata and `audit_log meta:` values are merged together automatically.

### Actor display name snapshot

`whodunnit_snapshot` stores the actor's display name at write time so entries remain meaningful even after the actor record is deleted:

```ruby
entry.whodunnit_snapshot  # => "Alice"  (even if the User record is later deleted)
```

The default display proc uses `actor.name` if available, otherwise `actor.to_s`. Override globally in an initializer:

```ruby
RailsAuditLog.whodunnit_display = ->(actor) { actor.email }
```

### Object snapshot storage

By default every entry stores a full `object` snapshot of the pre-change state alongside `object_changes`. This makes `reify` and `version_at` reliable without any database lookups:

```ruby
entry.object          # => { "id" => 1, "title" => "v1", ... }
entry.object_changes  # => { "title" => ["v1", "v2"] }
```

To save storage at the cost of reduced reification accuracy, switch to diff-only mode:

```ruby
RailsAuditLog.store_snapshot = false
```

### Separate audit database

Route all audit writes to a dedicated database by setting `connects_to` in an initializer. The engine applies it to `AuditLogEntry` at boot:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.connects_to = {
  database: { writing: :audit_log, reading: :audit_log }
}
```

The key (e.g. `:audit_log`) must match a database key in `config/database.yml`. All reads and writes on `AuditLogEntry` — including `batch_audit` inserts and `WriteAuditLogJob` — use that connection automatically.

### Test helpers

**`RailsAuditLog::TestHelpers`** — silences audit tracking inside a block; useful in FactoryBot factories and seed data:

```ruby
# spec/rails_helper.rb
require "rails_audit_log/test_helpers"

RSpec.configure do |config|
  config.include RailsAuditLog::TestHelpers
end
```

```ruby
# Or in a FactoryBot factory:
after(:create) { |p| without_audit_log { p.update!(cached_at: Time.current) } }
```

`without_audit_log` is a prefix-free wrapper around `RailsAuditLog.disable` — thread-safe and restores tracking even if the block raises.

**`RailsAuditLog::Matchers`** (RSpec) — add to `spec/rails_helper.rb`:

```ruby
require "rails_audit_log/matchers"

RSpec.configure do |config|
  config.include RailsAuditLog::Matchers
end
```

```ruby
expect(post).to have_audit_log_entry
expect(post).to have_audit_log_entry(:update)
expect(post).to have_audit_log_entry(:update).touching(:title)

expect { post.update!(title: "New") }.to create_audit_log_entry(event: :update).touching(:title)
```

**`RailsAuditLog::MinitestAssertions`** — add to `test/test_helper.rb`:

```ruby
require "rails_audit_log/minitest_assertions"

class ActiveSupport::TestCase
  include RailsAuditLog::MinitestAssertions
end
```

```ruby
assert_audit_log_entry post, event: :update, touching: :title
refute_audit_log_entry post, event: :destroy
```

## Stability and versioning

[↑ Table of contents](#table-of-contents)

`rails_audit_log` follows [Semantic Versioning](https://semver.org/) from 1.0.0. The public API is everything documented in this README. Anything not listed here is internal and may change between minor versions.

| Version bump | Meaning |
|---|---|
| **Patch** (1.0.x) | Bug fixes only — no API changes |
| **Minor** (1.x.0) | New features, backward-compatible |
| **Major** (x.0.0) | Breaking changes with a documented migration path |

### Public API surface

**Module-level** — `RailsAuditLog`

| Method / accessor | Purpose |
|---|---|
| `.configure { \|config\| }` | Block-style configuration |
| `.with_actor(actor) { }` | Set whodunnit context for a block |
| `.disable { }` | Suppress all audit writes for a block |
| `.enabled?` | Whether audit writes are active |
| `.audit_log_reason(value) { }` | Attach a free-text reason for a block |
| `.batch_audit { }` | Buffer writes and flush with a single `insert_all!` |
| `.version_at(record, time)` | Reconstruct record state at a point in time |
| `.authenticate { }` | Gate web dashboard access |
| `.ignored_attributes=` | Global columns excluded from all models |
| `.store_snapshot=` | Store full object snapshot alongside diffs |
| `.capture_request_metadata=` | Capture `remote_ip` and `user_agent` |
| `.version_limit=` | Global entry cap per record |
| `.async=` | Write audit entries via `WriteAuditLogJob` |
| `.connects_to=` | Route `AuditLogEntry` to a separate database |
| `.page_size=` | Entries per page in the web dashboard |
| `.whodunnit_display=` | Proc for actor display name snapshot |
| `.retention_period=` | Global time-based TTL for audit entries |

**Concerns**

| Class | Include in | Key methods |
|---|---|---|
| `RailsAuditLog::Auditable` | ActiveRecord models | `audit_log(only:, ignore:, meta:, associations:, version_limit:, async:)`, `skip_audit_log { }` |
| `RailsAuditLog::Controller` | ActionController | `audit_log_actor { }` |

**Model — `RailsAuditLog::AuditLogEntry`**

Scopes: `created_events`, `updated_events`, `destroyed_events`, `by_actor`, `for_resource`, `since`, `until`, `touching`, `slim`, `for_period`

Instance methods: `reify`, `previous`, `next`, `diff`, `changed_attributes`, `actor`

Constants: `EVENTS`, `BLOB_COLUMNS`, `PERIODS`

**Testing helpers**

| Module | Require | Usage |
|---|---|---|
| `RailsAuditLog::Matchers` | `require "rails_audit_log/matchers"` | RSpec: `have_audit_log_entry`, `create_audit_log_entry` |
| `RailsAuditLog::MinitestAssertions` | `require "rails_audit_log/minitest_assertions"` | Minitest: `assert_audit_log_entry`, `refute_audit_log_entry` |
| `RailsAuditLog::TestHelpers` | `require "rails_audit_log/test_helpers"` | `without_audit_log { }` |

**Jobs** (enqueued internally; configure via ActiveJob)

`RailsAuditLog::WriteAuditLogJob` — do not instantiate directly; enqueued when `async: true` is set.

**Generators**

`rails generate rails_audit_log:install` · `rails generate rails_audit_log:initializer`

---

## Migrating from PaperTrail

[↑ Table of contents](#table-of-contents)

Run the migration generator to produce a timestamped data migration:

```bash
bin/rails generate rails_audit_log:migrate_from_paper_trail
bin/rails db:migrate
```

The generated migration reads every row from PaperTrail's `versions` table and inserts it into `audit_log_entries`.

### Column mapping

| PaperTrail `versions` | `audit_log_entries` | Notes |
|---|---|---|
| `item_type` | `item_type` | Direct copy |
| `item_id` | `item_id` | Direct copy |
| `event` | `event` | `create` / `update` / `destroy` only; other values are skipped |
| `object_changes` | `object_changes` | YAML or JSON → JSON (see below) |
| `object` | `object` | YAML or JSON → JSON (see below) |
| `whodunnit` | `whodunnit_snapshot` | PaperTrail stores actor as a plain string |
| `created_at` | `created_at` | Direct copy |
| — | `actor_type` / `actor_id` | **Not populated** — cannot be inferred from a string `whodunnit` |

### YAML and JSON serialization

PaperTrail serializes `object` and `object_changes` as **YAML** by default and as **JSON** when `PaperTrail.serializer = PaperTrail::Serializers::JSON` is configured. The migration handles both transparently — it tries JSON first, then falls back to YAML (with a permissive class list for the Ruby types PaperTrail commonly serializes).

### Compatibility shim for gradual migration

If you need your codebase to keep using PaperTrail's API while migrating, include `RailsAuditLog::PaperTrailCompat` alongside `Auditable`:

```ruby
require "rails_audit_log/paper_trail_compat"

class Article < ApplicationRecord
  include RailsAuditLog::Auditable
  include RailsAuditLog::PaperTrailCompat
end
```

This adds the familiar PaperTrail surface:

```ruby
article.versions                          # audit_log_entries ordered oldest-first
article.paper_trail.version               # most recent AuditLogEntry
article.paper_trail.previous_version      # reconstructed previous state (reify)
article.paper_trail.originator            # whodunnit_snapshot string
article.paper_trail.version_at(1.week.ago) # reconstructed state at a point in time
```

`AuditLogEntry#reify` already matches PaperTrail's `Version#reify` — no additional alias needed.

### What is not migrated

- `versions` rows with an `event` value outside `create`, `update`, `destroy` (custom events added by some apps)
- `actor_type` and `actor_id` — PaperTrail's `whodunnit` is a plain string and does not identify the actor model

---

## Companion gems

[↑ Table of contents](#table-of-contents)

> Coming in the 1.x series

| Gem | What it adds |
|---|---|
| `rails_audit_log-graphql` | Mountable GraphQL endpoint at `/audit/graphql` — queryable audit trail for API-first apps without forcing `graphql-ruby` on users who don't need it |

Each companion gem declares `rails_audit_log` as a dependency so you only add what you use.

## Requirements

[↑ Table of contents](#table-of-contents)

- Ruby >= 3.3
- Rails >= 7.2

## Performance

[↑ Table of contents](#table-of-contents)

See [BENCHMARKS.md](BENCHMARKS.md) for write throughput, `batch_audit` gains, query performance, storage efficiency, and notes on comparing against PaperTrail. To run the suite locally:

```bash
bundle exec rake dev:setup
bundle exec rake benchmark
```

## Contributing

[↑ Table of contents](#table-of-contents)

Bug reports and pull requests are welcome on [GitHub](https://github.com/eclectic-coding/rails_audit_log).

## License

[↑ Table of contents](#table-of-contents)

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).