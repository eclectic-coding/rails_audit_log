require "rails/generators"
require "rails/generators/active_record"

module RailsAuditLog
  module Generators
    class EncryptionGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates an ActiveRecord::Encryption config initializer and a data migration " \
           "that re-encrypts existing audit entries for models using audit_log encrypt: true."

      def create_initializer_file
        template "rails_audit_log_encryption.rb",
                 "config/initializers/rails_audit_log_encryption.rb"
      end

      def create_migration_file
        migration_template(
          "encrypt_rails_audit_log_entries.rb",
          "db/migrate/encrypt_rails_audit_log_entries.rb"
        )
      end

      def print_next_steps
        say ""
        say "Next steps:", :green
        say "  1. Run `bin/rails db:encryption:init` to generate encryption keys"
        say "     and store them in config/credentials.yml.enc."
        say "  2. Review config/initializers/rails_audit_log_encryption.rb and wire"
        say "     the generated keys into ActiveRecord::Encryption."
        say "  3. Add `audit_log encrypt: true` (or set RailsAuditLog.encrypt = true)"
        say "     on the models whose audit data you want to protect."
        say "  4. Edit the generated migration — add your encrypted model class names"
        say "     to ENCRYPTED_MODELS — then run `bin/rails db:migrate`."
        say ""
      end
    end
  end
end
