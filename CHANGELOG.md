# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RailsAuditLog::AuditLogEntry` model backed by an `audit_log_entries` table with `event`, `item_type`, `item_id`, `object_changes` (JSON), `actor_type`, `actor_id`, and `created_at` columns
- Polymorphic `belongs_to :item` (required) and `belongs_to :actor` (optional) associations
- `.creates`, `.updates`, and `.destroys` scopes
- Install generator: `bin/rails generate rails_audit_log:install` creates the `audit_log_entries` migration

[Unreleased]: https://github.com/eclectic-coding/rails_audit_log/compare/main...HEAD