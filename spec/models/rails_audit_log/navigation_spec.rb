require "rails_helper"

RSpec.describe RailsAuditLog::AuditLogEntry, "version chain navigation" do
  let!(:post) { Post.create!(title: "v1") }

  before do
    post.update!(title: "v2")
    post.update!(title: "v3")
  end

  let(:entries)       { post.audit_log_entries.order(:id) }
  let(:create_entry)  { entries[0] }
  let(:update1_entry) { entries[1] }
  let(:update2_entry) { entries[2] }

  describe "#previous" do
    it "returns nil for the first entry in the chain" do
      expect(create_entry.previous).to be_nil
    end

    it "returns the create entry when called on the first update" do
      expect(update1_entry.previous).to eq(create_entry)
    end

    it "returns the immediately preceding entry" do
      expect(update2_entry.previous).to eq(update1_entry)
    end

    it "does not cross item boundaries" do
      other_entry = Post.create!(title: "Other").audit_log_entries.first
      expect(other_entry.previous).to be_nil
    end
  end

  describe "#next" do
    it "returns the first update entry when called on the create" do
      expect(create_entry.next).to eq(update1_entry)
    end

    it "returns the immediately following entry" do
      expect(update1_entry.next).to eq(update2_entry)
    end

    it "returns nil for the last entry in the chain" do
      expect(update2_entry.next).to be_nil
    end

    it "does not cross item boundaries" do
      other_entry = Post.create!(title: "Other").audit_log_entries.first
      expect(other_entry.next).to be_nil
    end
  end
end
