# Contributing to RailsAuditLog

Bug reports and pull requests are welcome on [GitHub](https://github.com/eclectic-coding/rails_audit_log).

## Development setup

Clone the repo and install dependencies:

```bash
git clone https://github.com/eclectic-coding/rails_audit_log.git
cd rails_audit_log
bundle install
```

Set up the development database and seed it with realistic audit data:

```bash
bundle exec rake dev:setup
bundle exec rake dev:seed
```

Start the dummy app to explore the web dashboard:

```bash
cd spec/dummy && bin/rails server
# Visit http://localhost:3000/audit_entries
```

## Running tests

```bash
# Full CI suite (bundle-audit + rubocop + zeitwerk + rspec)
bundle exec rake

# Tests only
bundle exec rspec

# Single file
bundle exec rspec spec/models/rails_audit_log/auditable_spec.rb

# Single example
bundle exec rspec spec/models/rails_audit_log/auditable_spec.rb:42

# Lint only
bin/rubocop
```

The test suite uses the dummy app's schema directly — no migrations are needed before running specs.

## Branch workflow

- Work on a `feat/*` or `chore/*` branch. Never commit directly to `main`.
- Keep PRs focused on a single concern.
- Add a `## [Unreleased]` entry to `CHANGELOG.md` on your branch before opening a PR.

## CHANGELOG conventions

New entries go under `## [Unreleased]` at the top of `CHANGELOG.md`. Sections within each version must appear in this order — omit sections with no entries:

1. `### Added`
2. `### Changed`
3. `### Fixed`

## Code style

This project uses RuboCop. Run `bin/rubocop` before pushing. The full CI suite (`bundle exec rake`) also runs it — a lint failure blocks merge.

## Reporting bugs

Open an issue on GitHub with:

- Ruby and Rails versions (`ruby -v`, `rails -v`)
- Gem version
- A minimal reproduction case or failing spec

## Submitting a pull request

1. Fork the repo and create a `feat/*` or `chore/*` branch.
2. Add tests covering the change.
3. Run `bundle exec rake` and make sure everything passes.
4. Add a `## [Unreleased]` entry to `CHANGELOG.md`.
5. Open a PR — describe *what* changed and *why*.

## License

By contributing you agree that your code will be released under the [MIT License](https://opensource.org/licenses/MIT).