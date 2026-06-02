require "rails_helper"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "generators/rails_audit_log/tenant/tenant_generator"

RSpec.describe RailsAuditLog::Generators::TenantGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests RailsAuditLog::Generators::TenantGenerator
  destination File.expand_path("../../../tmp/generator", __dir__)

  before { prepare_destination }

  describe "migration" do
    before { run_generator }

    let(:migration_file) { Dir["#{destination_root}/db/migrate/*_add_tenant_id_to_audit_log_entries.rb"].first }
    let(:content) { File.read(migration_file) }

    it "creates the migration file" do
      expect(migration_file).not_to be_nil
    end

    it "defines AddTenantIdToAuditLogEntries" do
      expect(content).to include("class AddTenantIdToAuditLogEntries")
    end

    it "adds tenant_id as a string column" do
      expect(content).to include("add_column :audit_log_entries, :tenant_id, :string")
    end

    it "adds an index on tenant_id" do
      expect(content).to include("add_index  :audit_log_entries, :tenant_id")
    end
  end
end
