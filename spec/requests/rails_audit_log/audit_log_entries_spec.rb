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

    it "displays the entry count" do
      Post.create!(title: "Hello")
      get "/audit/audit_log_entries"
      expect(response.body).to include("1 entries")
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
