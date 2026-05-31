require "rails_helper"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "generators/rails_audit_log/migrate_from_paper_trail/migrate_from_paper_trail_generator"

RSpec.describe RailsAuditLog::Generators::MigrateFromPaperTrailGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests RailsAuditLog::Generators::MigrateFromPaperTrailGenerator
  destination File.expand_path("../../../tmp/generator", __dir__)

  before { prepare_destination }

  describe "migration" do
    before { run_generator }

    let(:migration_path) { Dir["#{destination_root}/db/migrate/*_migrate_from_paper_trail.rb"].first }
    let(:content)        { File.read(migration_path) }

    it "creates the migration file" do
      expect(migration_path).not_to be_nil
    end

    it "is irreversible" do
      expect(content).to include("IrreversibleMigration")
    end

    it "maps the core columns" do
      expect(content).to include("item_type")
      expect(content).to include("item_id")
      expect(content).to include("event")
      expect(content).to include("object_changes")
      expect(content).to include("whodunnit_snapshot")
      expect(content).to include("created_at")
    end

    it "guards against unsupported events" do
      expect(content).to include("VALID_EVENTS")
    end

    it "handles YAML and JSON serialization" do
      expect(content).to include("JSON.parse")
      expect(content).to include("YAML.safe_load")
    end

    it "processes records in batches" do
      expect(content).to include("in_batches")
      expect(content).to include("BATCH_SIZE")
    end

    it "checks for the versions table before migrating" do
      expect(content).to include("table_exists?(:versions)")
    end
  end
end
