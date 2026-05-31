# Roadmap

`rails_audit_log` is a modern, Zeitwerk-native Rails engine for auditing ActiveRecord changes. It replaces [PaperTrail](https://github.com/paper-trail-gem/paper_trail) with a cleaner query API, JSON-first storage, and no legacy baggage.

Each milestone below ships enough to be useful on its own. The 0.x series builds toward feature parity with PaperTrail; 1.0 stabilises the public API and adds the migration path. The 1.x series extends with advanced production features, one per release.

---


## 1.2.0 — Encryption at rest

> Encrypt sensitive audit data using Rails' built-in `encrypts` API.

- `audit_log encrypt: true` — opt-in per model; encrypts `object_changes` and `object` columns at write time using `ActiveRecord::Encryption`
- `RailsAuditLog.encrypt = true` — global default; per-model `encrypt: false` opts out
- Install generator produces the required `config/credentials.yml.enc` keys and `config/initializers/rails_audit_log.rb` encryption config snippet
- Transparent decryption on read — existing query API (`.diff`, `.reify`, `.touching`) works unchanged
- Migration generator adds `encrypted_` column variants for zero-downtime upgrades

---

## 1.3.0 — Multi-tenancy

> Built-in tenant scoping so audit entries are naturally isolated in multi-tenant apps.

- `audit_log tenant: -> { Current.tenant_id }` — zero-argument lambda evaluated at write time and stored in a dedicated `tenant_id` column
- `AuditLogEntry.for_tenant(id)` scope — filters all queries to a single tenant; composable with existing scopes
- `RailsAuditLog.current_tenant { Current.tenant_id }` — global tenant resolver used when no per-model override is set
- Dashboard `/audit` automatically scopes to the current tenant when the resolver is configured
- Acts As Tenant compatibility helper: `RailsAuditLog.acts_as_tenant!` wires the resolver to `ActsAsTenant.current_tenant`
- Migration generator adds the `tenant_id` column and index

---

## 1.4.0 — Event streaming

> Publish audit entries to an external message bus as they are written.

- Adapter interface: `RailsAuditLog.streaming_adapter = MyAdapter` — any object implementing `#publish(entry)`
- Built-in `ActiveSupport::Notifications` adapter — zero-dependency pub/sub for in-process consumers
- `ActiveJob` adapter — serialises each entry as a job payload and enqueues it; backend-agnostic
- Kafka adapter (optional, separate gem `rails_audit_log-kafka`) — publishes via `WaterDrop`
- SQS adapter (optional, separate gem `rails_audit_log-sqs`) — publishes via `aws-sdk-sqs`
- Streaming is async-safe: `batch_audit` flushes the buffer first, then publishes each entry

---

## 1.5.0 — GraphQL API (`rails_audit_log-graphql`)

> Queryable audit trail for API-first apps — shipped as a standalone companion gem.

Published separately as **`rails_audit_log-graphql`** so `graphql-ruby` is never a transitive dependency for users who don't need it. Add both gems and mount the extra engine:

```ruby
# Gemfile
gem "rails_audit_log"
gem "rails_audit_log-graphql"

# config/routes.rb
mount RailsAuditLog::Engine,          at: "/audit"
mount RailsAuditLog::GraphQL::Engine, at: "/audit/graphql"
```

Authentication re-uses `RailsAuditLog.authenticate` — nothing extra to configure.

Features:
- `AuditLogEntryType` — GraphQL object type exposing all public fields
- `Query.auditLogEntries(event:, itemType:, itemId:, actorId:, since:, until:, page:)` — filterable, paginated query
- `Query.auditLogEntry(id:)` — single entry lookup with full diff
- `Subscription.auditLogEntryCreated(itemType:, itemId:)` — real-time stream for a specific resource (requires Action Cable)
