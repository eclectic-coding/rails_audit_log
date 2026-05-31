require "rails/generators"
require "rails/generators/active_record"

module RailsAuditLog
  module Generators
    class MigrateFromPaperTrailGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a data migration that copies PaperTrail versions to audit_log_entries."

      def create_migration_file
        migration_template(
          "migrate_from_paper_trail.rb",
          "db/migrate/migrate_from_paper_trail.rb"
        )
      end
    end
  end
end
