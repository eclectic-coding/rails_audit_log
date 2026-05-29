require "rails/generators"
require "rails/generators/active_record"

module RailsAuditLog
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates the audit_log_entries migration in your application."

      def create_migration_file
        migration_template(
          "create_audit_log_entries.rb",
          "db/migrate/create_audit_log_entries.rb"
        )
      end
    end
  end
end
