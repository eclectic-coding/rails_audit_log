require "rails_helper"
require "rails/generators/testing/behavior"
require "rails/generators/testing/assertions"
require "generators/rails_audit_log/encryption/encryption_generator"

RSpec.describe RailsAuditLog::Generators::EncryptionGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::Assertions
  include FileUtils

  tests RailsAuditLog::Generators::EncryptionGenerator
  destination File.expand_path("../../../tmp/generator", __dir__)

  before { prepare_destination }

  describe "initializer" do
    before { run_generator }

    let(:initializer_path) { "#{destination_root}/config/initializers/rails_audit_log_encryption.rb" }
    let(:content) { File.read(initializer_path) }

    it "creates the initializer file" do
      expect(File.exist?(initializer_path)).to be true
    end

    it "references db:encryption:init" do
      expect(content).to include("db:encryption:init")
    end

    it "configures ActiveRecord::Encryption primary_key from credentials" do
      expect(content).to include("config.active_record.encryption.primary_key")
      expect(content).to include(":primary_key")
    end

    it "configures ActiveRecord::Encryption deterministic_key from credentials" do
      expect(content).to include("config.active_record.encryption.deterministic_key")
      expect(content).to include(":deterministic_key")
    end

    it "configures ActiveRecord::Encryption key_derivation_salt from credentials" do
      expect(content).to include("config.active_record.encryption.key_derivation_salt")
      expect(content).to include(":key_derivation_salt")
    end

    it "documents audit_log encrypt: true usage" do
      expect(content).to include("audit_log encrypt: true")
    end

    it "documents audit_log encrypt: false opt-out" do
      expect(content).to include("audit_log encrypt: false")
    end

    it "documents RailsAuditLog.encrypt = true global option" do
      expect(content).to include("RailsAuditLog.encrypt = true")
    end
  end

  describe "migration" do
    before { run_generator }

    let(:migration_file) { Dir["#{destination_root}/db/migrate/*_encrypt_rails_audit_log_entries.rb"].first }
    let(:content) { File.read(migration_file) }

    it "creates the migration file" do
      expect(migration_file).not_to be_nil
    end

    it "defines EncryptRailsAuditLogEntries" do
      expect(content).to include("class EncryptRailsAuditLogEntries")
    end

    it "uses the ENCRYPTION_MARKER constant" do
      expect(content).to include("ENCRYPTION_MARKER")
    end

    it "has an ENCRYPTED_MODELS placeholder" do
      expect(content).to include("ENCRYPTED_MODELS")
    end

    it "includes batch processing" do
      expect(content).to include("find_in_batches")
    end

    it "skips already-encrypted entries" do
      expect(content).to include("encrypted?")
    end

    it "is irreversible" do
      expect(content).to include("IrreversibleMigration")
    end
  end
end
