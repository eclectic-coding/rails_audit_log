require "rails/generators"
require "rails/generators/active_record"

module RailsAuditLog
  module Generators
    class TenantGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a migration that adds a tenant_id column and index to audit_log_entries."

      def create_migration_file
        migration_template(
          "add_tenant_id_to_audit_log_entries.rb",
          "db/migrate/add_tenant_id_to_audit_log_entries.rb"
        )
      end

      def print_next_steps
        say ""
        say "Next steps:", :green
        say "  1. Run `bin/rails db:migrate` to add the tenant_id column."
        say "  2. Set a global resolver in your initializer:"
        say "       RailsAuditLog.current_tenant { Current.tenant_id }"
        say "     or per-model:"
        say "       audit_log tenant: -> { Current.tenant_id }"
        say "  3. Use AuditLogEntry.for_tenant(id) to scope queries to a tenant."
        say ""
      end
    end
  end
end
