source "https://rubygems.org"

# Specify your gem's dependencies in rails_audit_log.gemspec.
gemspec

gem "puma"

gem "sqlite3"

# Postgres adapter — used only in the postgres CI job.
# Local devs without libpq can opt out:
#   bundle config set --local without db_postgres
group :db_postgres do
  gem "pg", require: false
end

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

gem "bundler-audit", require: false

group :test do
  gem "rspec-rails"
  gem "simplecov", require: false
  gem "simplecov-json", require: false
end

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
