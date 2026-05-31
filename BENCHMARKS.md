# Benchmarks

Performance measurements for `rails_audit_log` compared directly against PaperTrail 17.

## Reference environment

| Item      | Value                         |
|-----------|-------------------------------|
| Ruby      | 4.0.5                         |
| Rails     | 8.1.3                         |
| Database  | SQLite (development)          |
| PaperTrail | 17.0.0                       |
| Hardware  | Apple M-series (arm64-darwin) |

## Running the suite

```bash
bundle exec rake dev:setup          # create the development database
bundle exec ruby benchmarks/suite.rb
bundle exec rake dev:reset          # restore seeds afterwards
```

The suite compares `rails_audit_log` against PaperTrail side-by-side in every section. Each library's callbacks are disabled during the other's measurement so only one auditing system writes per data point.

---

## 1. Write throughput: create

| Library          | Throughput  | vs PaperTrail      |
|------------------|-------------|--------------------|
| `rails_audit_log` | ~773 i/s   | **1.18× faster**   |
| PaperTrail       | ~657 i/s    | baseline           |

## 2. Write throughput: update

| Library          | Throughput   | vs PaperTrail     |
|------------------|--------------|-------------------|
| `rails_audit_log` | ~2 060 i/s  | **1.32× faster**  |
| PaperTrail       | ~1 562 i/s   | baseline          |

Both libraries write a second row on every tracked change via `after_create`/`after_update` callbacks. The overhead is inherent to the approach. `rails_audit_log` is faster because it skips PaperTrail's YAML serialization and metadata lookups.

## 3. 50 creates: `batch_audit` vs PaperTrail

| Mode                                          | Throughput   | vs PaperTrail     |
|-----------------------------------------------|--------------|-------------------|
| `rails_audit_log` — `batch_audit` (1 INSERT)  | ~71 i/s      | **2.00× faster**  |
| `rails_audit_log` — individual (N INSERTs)    | ~43 i/s      | 1.21× faster      |
| PaperTrail — individual (N INSERTs)           | ~36 i/s      | baseline          |

`batch_audit` replaces N individual `INSERT` statements with a single `INSERT ... VALUES (…), (…), …` via `insert_all!`. The speedup grows with batch size. PaperTrail has no equivalent.

## 4. Query performance: last 25 entries

| Query                                                       | Throughput  | vs PaperTrail    |
|-------------------------------------------------------------|-------------|------------------|
| `AuditLogEntry.order(created_at: :desc).limit(25)`          | ~7 219 i/s  | **1.23× faster** |
| `.slim.order(created_at: :desc).limit(25)`                  | ~6 668 i/s  | 1.14× faster     |
| `PaperTrail::Version.order(created_at: :desc).limit(25)`    | ~5 852 i/s  | baseline         |

`.slim` excludes the three JSON blob columns (`object_changes`, `object`, `metadata`) from the `SELECT`. On rows with large blobs the gain grows significantly; on small rows it is similar to a full select.

## 5. Storage per entry

| Library           | Avg bytes  | Median bytes | Format |
|-------------------|------------|--------------|--------|
| `rails_audit_log` | ~135 bytes | ~135 bytes   | JSON   |
| PaperTrail        | ~336 bytes | ~336 bytes   | YAML   |

**~60% smaller** per entry with `rails_audit_log`. JSON is more compact than YAML and skips PaperTrail's `---\n- ruby/object:...` envelope. For a table with millions of entries this compounds into meaningful storage and I/O savings.