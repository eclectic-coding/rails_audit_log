# RailsAuditLog

[![CI](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml/badge.svg)](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/rails_audit_log.svg)](https://rubygems.org/gems/rails_audit_log)
[![Downloads](https://img.shields.io/gem/dt/rails_audit_log.svg)](https://rubygems.org/gems/rails_audit_log)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-ruby)](https://www.ruby-lang.org)
[![codecov](https://codecov.io/gh/eclectic-coding/rails_audit_log/branch/main/graph/badge.svg)](https://codecov.io/gh/eclectic-coding/rails_audit_log)

A modern, Zeitwerk-native Rails engine for auditing ActiveRecord changes. Tracks `create`, `update`, and `destroy` events with JSON-first storage, whodunnit actor context, and a clean query API.

## Installation

Add to your `Gemfile`:

```ruby
gem "rails_audit_log"
```

Run the install generator to create the migration:

```bash
bin/rails generate rails_audit_log:install
bin/rails db:migrate
```

## Usage

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

### Separate audit database

Route all audit writes to a dedicated database by setting `connects_to` in an initializer. The engine applies it to `AuditLogEntry` at boot:

```ruby
# config/initializers/rails_audit_log.rb
RailsAuditLog.connects_to = {
  database: { writing: :audit_log, reading: :audit_log }
}
```

The key (e.g. `:audit_log`) must match a database key in `config/database.yml`. All reads and writes on `AuditLogEntry` — including `batch_audit` inserts and `WriteAuditLogJob` — use that connection automatically.

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

#### Reify a single entry

`AuditLogEntry#reify` returns an unsaved ActiveRecord instance reflecting the record's state **before** the entry was recorded:

```ruby
article.update!(title: "v2")
entry = article.audit_log_entries.updated_events.last

previous = entry.reify
previous.title   # => "v1"  (the pre-update state)
previous.persisted? # => false
```

Returns `nil` for `create` entries (nothing existed before).

#### Reconstruct state at any point in time

```ruby
snapshot = RailsAuditLog.version_at(article, 1.week.ago)
snapshot.title  # => whatever the title was a week ago
```

Returns `nil` if the record had no history at that time or was already destroyed.

#### Navigate the version chain

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

### Test helper

`without_audit_log` silences audit tracking inside the block — useful in FactoryBot factories and seed data to avoid noise in the audit trail:

```ruby
# spec/rails_helper.rb (or spec/support/factory_helpers.rb)
require "rails_audit_log/test_helpers"

RSpec.configure do |config|
  config.include RailsAuditLog::TestHelpers
end

# Or include directly in FactoryBot definitions:
FactoryBot.define do
  factory :post do
    after(:create) { |p| without_audit_log { p.update!(cached_at: Time.current) } }
  end
end
```

`without_audit_log` is a prefix-free wrapper around `RailsAuditLog.disable` — thread-safe and restores tracking even if the block raises.

### Minitest assertions

Add to your `test/test_helper.rb`:

```ruby
require "rails_audit_log/minitest_assertions"

class ActiveSupport::TestCase
  include RailsAuditLog::MinitestAssertions
end
```

Then use the assertions in any test:

```ruby
assert_audit_log_entry post                                      # any entry
assert_audit_log_entry post, event: :update                      # update entry
assert_audit_log_entry post, event: :update, touching: :title    # touching title
refute_audit_log_entry post, event: :update                      # no update entry
assert_audit_log_entry post, event: :update, message: "custom"  # custom failure message
```

### RSpec matchers

Add to your `spec/rails_helper.rb` (or `spec_helper.rb`):

```ruby
require "rails_audit_log/matchers"

RSpec.configure do |config|
  config.include RailsAuditLog::Matchers
end
```

Then use the matchers in any spec:

```ruby
# Assert a record has a matching audit entry
expect(post).to have_audit_log_entry
expect(post).to have_audit_log_entry(:update)
expect(post).to have_audit_log_entry(:update).touching(:title)

# Assert a block creates a matching audit entry
expect { post.update!(title: "New") }.to create_audit_log_entry
expect { post.update!(title: "New") }.to create_audit_log_entry(event: :update)
expect { post.update!(title: "New") }.to create_audit_log_entry(event: :update).touching(:title)
```

## Requirements

- Ruby >= 3.3
- Rails >= 7.2

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/eclectic-coding/rails_audit_log).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).