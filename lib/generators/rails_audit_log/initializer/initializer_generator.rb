require "rails/generators"

module RailsAuditLog
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a commented RailsAuditLog initializer in config/initializers."

      def create_initializer_file
        template "rails_audit_log.rb", "config/initializers/rails_audit_log.rb"
      end
    end
  end
end
