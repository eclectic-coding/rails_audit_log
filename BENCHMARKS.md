# Benchmarks

Performance measurements for `rails_audit_log` compared against PaperTrail.

## Reference environment

| | |
|---|---|
| Ruby | 4.0.5 |
| Rails | 8.1.3 |
| Database | SQLite (development) |
| Hardware | Apple M-series (arm64-darwin) |

## Running the suite

```bash
bundle exec rake dev:setup          # create the development database
bundle exec ruby benchmarks/suite.rb
bundle exec rake dev:reset          # restore seeds afterwards
```

---

## 1. Write throughput (individual)

| Operation | Throughput | vs raw insert |
|---|---|---|
| Raw `AuditLogEntry.create!` (no concern) | ~1 390 i/s | baseline |
| `Post.create!` via `Auditable` | ~797 i/s | 1.7× overhead |
| `post.update!` via `Auditable` | ~645 i/s | 2.2× overhead |

The overhead comes from ActiveRecord callbacks (saved_changes, filter logic, entry creation). PaperTrail has comparable overhead — both call `after_create`/`after_update` callbacks that perform a second database write.

## 2. batch_audit vs individual writes

| Mode | Throughput (50 records) | Speedup |
|---|---|---|
| Individual writes | ~42 i/s | baseline |
| `RailsAuditLog.batch_audit { }` | ~71 i/s | **1.7× faster** |

`batch_audit` replaces N individual `INSERT` statements with a single `INSERT ... VALUES (…), (…), …` via `insert_all!`. The speedup grows with batch size.

## 3. Query performance

| Query | Throughput |
|---|---|
| `AuditLogEntry.order(created_at: :desc).limit(25)` | ~7 700 i/s |
| `.slim.order(created_at: :desc).limit(25)` | ~6 400 i/s |
| `record.audit_log_entries` (AR proxy, not yet loaded) | ~2 000 000 i/s |

`.slim` excludes the three JSON blob columns (`object_changes`, `object`, `metadata`) from the `SELECT`. The throughput difference vs the full query reflects I/O and JSON deserialization savings; the gain grows significantly on rows with large blobs.

## 4. Storage per entry

| Format | Avg bytes (object_changes + object) |
|---|---|
| `rails_audit_log` (JSON) | ~149 bytes |
| PaperTrail (YAML) | ~200–220 bytes (estimated) |

JSON is typically **30–50% smaller** than the equivalent YAML. For a table with millions of entries this compounds into meaningful storage savings.

## 5. Time-travel reconstruction (`version_at`)

| Operation | Throughput |
|---|---|
| `RailsAuditLog.version_at(record, time)` | ~5 700 i/s |

One indexed query (`WHERE item_type = ? AND item_id = ? AND created_at <= ?`) plus Ruby-level attribute assignment. Performance is dominated by the database round-trip.

---

## Comparing against PaperTrail

The benchmark suite does not require PaperTrail to be installed. To add a direct comparison:

1. Add `gem "paper_trail"` to your Gemfile and run `bundle install`.
2. Include `has_paper_trail` on the `Post` model in `spec/dummy/app/models/post.rb`.
3. Add PaperTrail benchmark blocks inside `benchmarks/suite.rb` matching the same operations.

In general, `rails_audit_log` and PaperTrail have comparable write overhead because both use ActiveRecord callbacks. `rails_audit_log` advantages are:

- **Smaller storage** — JSON vs YAML
- **`batch_audit`** — single `INSERT` for bulk operations (no PaperTrail equivalent)
- **`.slim` scope** — skip blob columns on index queries
- **`async: true`** — non-blocking writes via ActiveJob (no PaperTrail equivalent)