# RailsAuditLog

[![CI](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml/badge.svg)](https://github.com/eclectic-coding/rails_audit_log/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/rails_audit_log.svg)](https://badge.fury.io/rb/rails_audit_log)
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
article.audit_log_entries.count      # => 1
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

## Requirements

- Ruby >= 3.3
- Rails >= 7.2

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/eclectic-coding/rails_audit_log).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).