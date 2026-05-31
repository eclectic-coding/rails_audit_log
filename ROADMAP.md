# Roadmap

`rails_audit_log` is a modern, Zeitwerk-native Rails engine for auditing ActiveRecord changes. It replaces [PaperTrail](https://github.com/paper-trail-gem/paper_trail) with a cleaner query API, JSON-first storage, and no legacy baggage.

Each milestone below ships enough to be useful on its own. The 0.x series builds toward feature parity with PaperTrail; 1.0 stabilises the public API and adds the migration path. The 1.x series extends with advanced production features, one per release.

---

## 1.0.0 — Stable public API & migration

> Production-ready with a documented upgrade path from PaperTrail.

- Freeze and document the public API (no breaking changes after 1.0 without a major bump)
- `bin/rails generate rails_audit_log:migrate_from_paper_trail` — migration script that maps `versions` rows to `audit_log_entries`
- PaperTrail compatibility shim (`paper_trail_compat` concern) that adds `.versions`, `#paper_trail`, `version.reify` aliases for gradual migration
- Performance benchmark suite comparing throughput and storage to PaperTrail
- Full YARD API documentation
- CHANGELOG covering every public surface from 0.1 to 1.0

---

## 1.1.0 — Data retention policies

> Declarative TTL rules with automatic pruning so audit tables don't grow unbounded.

- `RailsAuditLog.retention_period = 90.days` — global time-based TTL; entries older than this are eligible for pruning
- `audit_log retain_for: 30.days` — per-model override; takes precedence over the global default
- `RailsAuditLog::PruneAuditLogJob` — background job that prunes expired entries; enqueue on a schedule via your job backend
- `bin/rails rails_audit_log:prune` — rake task for manual or cron-driven pruning
- `version_limit` and `retention_period` compose — an entry is pruned when it exceeds either constraint

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

## 1.5.0 — GraphQL API

> A mountable GraphQL endpoint for querying the audit trail from API-first apps.

- `AuditLogEntryType` — GraphQL object type exposing all public fields
- `Query.auditLogEntries(event:, itemType:, itemId:, actorId:, since:, until:, page:)` — filterable, paginated query
- `Query.auditLogEntry(id:)` — single entry lookup with full diff
- `Subscription.auditLogEntryCreated(itemType:, itemId:)` — real-time stream for a specific resource (requires Action Cable)
- Mounts at `/audit/graphql`; authentication re-uses `RailsAuditLog.authenticate`
- Optional: standalone gem `rails_audit_log-graphql` to avoid forcing `graphql-ruby` on all users