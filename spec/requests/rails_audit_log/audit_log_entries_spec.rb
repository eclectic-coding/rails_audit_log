require "rails_helper"

RSpec.describe "RailsAuditLog dashboard", type: :request do
  describe "GET /audit (root)" do
    it "returns 200" do
      get "/audit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /audit/audit_log_entries" do
    it "returns 200" do
      get "/audit/audit_log_entries"
      expect(response).to have_http_status(:ok)
    end

    it "shows the entry count" do
      Post.create!(title: "Hello")
      get "/audit/audit_log_entries"
      expect(response.body).to include("1 entry")
    end

    it "shows an empty state when there are no entries" do
      get "/audit/audit_log_entries"
      expect(response.body).to include("No audit entries yet.")
    end

    it "renders a table row for each entry on the page" do
      3.times { |i| Post.create!(title: "Post #{i}") }
      get "/audit/audit_log_entries"
      expect(response.body).to include("create").and include("Post")
    end

    context "with more than PER_PAGE entries" do
      before do
        (RailsAuditLog::AuditLogEntriesController::PER_PAGE + 2).times do |i|
          RailsAuditLog::AuditLogEntry.create!(
            event: "create", item_type: "Post", item_id: i + 1,
            object_changes: { "title" => [nil, "Post #{i}"] }
          )
        end
      end

      it "shows pagination controls" do
        get "/audit/audit_log_entries"
        expect(response.body).to include("Next →")
      end

      it "navigates to page 2" do
        get "/audit/audit_log_entries", params: { page: 2 }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("← Previous")
      end

      it "clamps page below 1 to page 1" do
        get "/audit/audit_log_entries", params: { page: 0 }
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("← Previous")
      end
    end
  end

  describe "GET /audit/audit_log_entries/:id" do
    it "returns 200" do
      entry = Post.create!(title: "Hello").audit_log_entries.first
      get "/audit/audit_log_entries/#{entry.id}"
      expect(response).to have_http_status(:ok)
    end
  end
end
