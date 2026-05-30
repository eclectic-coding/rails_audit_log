# Roadmap

`rails_audit_log` is a modern, Zeitwerk-native Rails engine for auditing ActiveRecord changes. It replaces [PaperTrail](https://github.com/paper-trail-gem/paper_trail) with a cleaner query API, JSON-first storage, and no legacy baggage.

Each milestone below ships enough to be useful on its own. The 0.x series builds toward feature parity with PaperTrail; 1.0 stabilises the public API and adds the migration path.

---

## 0.9.0 — Web dashboard

> A mountable UI for browsing the audit trail.

- Mountable engine route: `mount RailsAuditLog::Engine, at: "/audit"`
- Index view: paginated list of all audit entries (newest first)
- Per-resource view: all entries for a given record, with inline diff rendering
- Filter by actor, event type, time range, resource class
- Diff display: side-by-side or inline attribute-level change highlighting
- Asset delivery via propshaft, importmaps, and CDN-pinned turbo + stimulus (same engine pattern as `solid_stack_web`; CSS served as normal files, no inline style injection)
- Configurable authentication block: `RailsAuditLog.authenticate { |c| c.current_user&.admin? }`

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

## Post-1.0 ideas

These are out of scope for 1.0 but worth tracking:

- **Encryption** — encrypt `object_changes` at rest via Rails `encrypts`
- **Multi-tenancy** — built-in tenant scoping (Acts As Tenant integration)
- **GraphQL API** — queryable audit log over GraphQL
- **Event streaming** — publish audit entries to a message bus (Kafka, SQS) as they are written
- **Data retention policies** — declarative TTL rules with automatic pruning jobs
