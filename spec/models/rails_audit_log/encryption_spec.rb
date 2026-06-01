require "rails_helper"

RSpec.describe "RailsAuditLog::Auditable encrypt: true" do
  let(:encrypted_class) do
    klass = Class.new(ApplicationRecord) do
      self.table_name = "posts"
      def self.name = "EncryptedPost"
      include RailsAuditLog::Auditable
      audit_log encrypt: true
    end
    stub_const("EncryptedPost", klass)
    klass
  end

  describe "create event" do
    it "stores object_changes as an encrypted envelope" do
      record = encrypted_class.create!(title: "Secret")
      raw = RailsAuditLog::AuditLogEntry
        .where(item_type: "EncryptedPost", item_id: record.id)
        .first
      raw_value = raw.read_attribute(:object_changes)
      expect(raw_value).to be_a(Hash)
      expect(raw_value.keys).to eq([RailsAuditLog::AuditLogEntry::ENCRYPTION_MARKER])
    end

    it "transparently decrypts object_changes on read" do
      record = encrypted_class.create!(title: "Secret")
      entry = record.audit_log_entries.first
      expect(entry.object_changes["title"]).to eq([nil, "Secret"])
    end

    it "stores object snapshot encrypted on update when store_snapshot is true" do
      allow(RailsAuditLog).to receive(:store_snapshot).and_return(true)
      record = encrypted_class.create!(title: "Before")
      record.update!(title: "After")
      entry = record.audit_log_entries.find_by(event: "update")
      raw_object = entry.read_attribute(:object)
      expect(raw_object.keys).to eq([RailsAuditLog::AuditLogEntry::ENCRYPTION_MARKER])
    end
  end

  describe "update event" do
    it "encrypts object_changes for update entries" do
      record = encrypted_class.create!(title: "Before")
      record.update!(title: "After")
      entry = record.audit_log_entries.find_by(event: "update")
      expect(entry.object_changes["title"]).to eq(["Before", "After"])
    end
  end

  describe "destroy event" do
    it "encrypts object_changes for destroy entries" do
      record = encrypted_class.create!(title: "Gone")
      id = record.id
      record.destroy!
      entry = RailsAuditLog::AuditLogEntry
        .where(item_type: "EncryptedPost", item_id: id, event: "destroy")
        .first
      expect(entry.object_changes["title"]).to eq(["Gone", nil])
    end
  end

  describe "AuditLogEntry instance methods" do
    it "#diff returns decrypted from/to pairs" do
      record = encrypted_class.create!(title: "Before")
      record.update!(title: "After")
      entry = record.audit_log_entries.find_by(event: "update")
      expect(entry.diff["title"]).to eq({ from: "Before", to: "After" })
    end

    it "#changed_attributes returns decrypted attribute names" do
      record = encrypted_class.create!(title: "Hello")
      entry = record.audit_log_entries.first
      expect(entry.changed_attributes).to include("title")
    end

    it "#reify reconstructs the pre-change state" do
      record = encrypted_class.create!(title: "Before")
      record.update!(title: "After")
      entry = record.audit_log_entries.find_by(event: "update")
      prior = entry.reify
      expect(prior.title).to eq("Before")
    end
  end

  describe "non-encrypted model is unaffected" do
    it "stores object_changes as a plain hash for non-encrypted models" do
      post = Post.create!(title: "Public")
      entry = post.audit_log_entries.first
      raw = entry.read_attribute(:object_changes)
      expect(raw).to be_a(Hash)
      expect(raw.keys).not_to include(RailsAuditLog::AuditLogEntry::ENCRYPTION_MARKER)
    end
  end
end
