require "rails_helper"

RSpec.describe "Dashboard authentication", type: :request do
  around do |example|
    original = RailsAuditLog.instance_variable_get(:@authenticate)
    example.run
  ensure
    RailsAuditLog.instance_variable_set(:@authenticate, original)
  end

  context "when no authenticate block is set" do
    it "allows all requests through" do
      RailsAuditLog.instance_variable_set(:@authenticate, nil)
      get "/audit"
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the block returns truthy" do
    it "allows the request through" do
      RailsAuditLog.authenticate { true }
      get "/audit"
      expect(response).to have_http_status(:ok)
    end

    it "supports controller-argument style" do
      RailsAuditLog.authenticate { |_c| true }
      get "/audit"
      expect(response).to have_http_status(:ok)
    end
  end

  context "when the block returns falsy" do
    it "returns 401 with a Basic auth challenge" do
      RailsAuditLog.authenticate { false }
      get "/audit"
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include("Basic")
    end

    it "challenges on all dashboard routes" do
      RailsAuditLog.authenticate { nil }
      get "/audit/audit_log_entries"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "RailsAuditLog.authenticate reader" do
    it "returns nil when no block has been set" do
      RailsAuditLog.instance_variable_set(:@authenticate, nil)
      expect(RailsAuditLog.authenticate).to be_nil
    end

    it "returns the block after it is set" do
      RailsAuditLog.authenticate { true }
      expect(RailsAuditLog.authenticate).to be_a(Proc)
    end
  end
end
