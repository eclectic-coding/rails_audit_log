# Roadmap

`rails_audit_log` is a modern, Zeitwerk-native Rails engine for auditing ActiveRecord changes. It replaces [PaperTrail](https://github.com/paper-trail-gem/paper_trail) with a cleaner query API, JSON-first storage, and no legacy baggage.

Each milestone below ships enough to be useful on its own. The 0.x series builds toward feature parity with PaperTrail; 1.0 stabilises the public API and adds the migration path. The 1.x series extends with advanced production features, one per release.

---


## 1.4.0 — Event streaming

> Publish audit entries to an external message bus as they are written.

- Kafka adapter (optional, separate gem `rails_audit_log-kafka`) — publishes via `WaterDrop`
- SQS adapter (optional, separate gem `rails_audit_log-sqs`) — publishes via `aws-sdk-sqs`

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
