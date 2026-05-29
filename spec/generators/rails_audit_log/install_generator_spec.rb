require "rails_helper"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "generators/rails_audit_log/install/install_generator"

RSpec.describe RailsAuditLog::Generators::InstallGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests RailsAuditLog::Generators::InstallGenerator
  destination File.expand_path("../../../tmp/generator", __dir__)

  before { prepare_destination }

  describe "migration" do
    before { run_generator }

    it "creates the migration file" do
      migration_file = Dir["#{destination_root}/db/migrate/*_create_audit_log_entries.rb"].first
      expect(migration_file).not_to be_nil
    end

    it "migration defines the audit_log_entries table" do
      migration = Dir["#{destination_root}/db/migrate/*_create_audit_log_entries.rb"].first
      content = File.read(migration)

      expect(content).to include("create_table :audit_log_entries")
      expect(content).to include("t.string  :event,")
      expect(content).to include("t.string  :item_type,")
      expect(content).to include("t.bigint  :item_id,")
      expect(content).to include("t.json    :object_changes")
      expect(content).to include("t.string  :actor_type")
      expect(content).to include("t.bigint  :actor_id")
      expect(content).to include("t.datetime :created_at,")
    end

    it "migration adds indexes" do
      migration = Dir["#{destination_root}/db/migrate/*_create_audit_log_entries.rb"].first
      content = File.read(migration)

      expect(content).to include("add_index :audit_log_entries, [:item_type, :item_id]")
      expect(content).to include("add_index :audit_log_entries, [:actor_type, :actor_id]")
      expect(content).to include("add_index :audit_log_entries, :event")
      expect(content).to include("add_index :audit_log_entries, :created_at")
    end
  end
end
