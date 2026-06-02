require "rails_helper"

RSpec.describe "RailsAuditLog dashboard tenant scoping", type: :request do
  after { RailsAuditLog.instance_variable_set(:@current_tenant, nil) }

  def make_entry(tenant_id:)
    RailsAuditLog::AuditLogEntry.create!(
      event: "create", item_type: "Post", item_id: 1,
      tenant_id: tenant_id
    )
  end

  describe "GET /audit/audit_log_entries" do
    it "shows all entries when no tenant resolver is configured" do
      make_entry(tenant_id: "acme")
      make_entry(tenant_id: "globex")
      get "/audit/audit_log_entries"
      expect(response.body).to include("2 entries")
    end

    it "scopes to the current tenant when resolver is configured" do
      make_entry(tenant_id: "acme")
      make_entry(tenant_id: "globex")
      RailsAuditLog.current_tenant { "acme" }
      get "/audit/audit_log_entries"
      expect(response.body).to include("1 entry")
    end

    it "shows no entries when resolver returns a tenant with no data" do
      make_entry(tenant_id: "globex")
      RailsAuditLog.current_tenant { "acme" }
      get "/audit/audit_log_entries"
      expect(response.body).to include("No audit entries found.")
    end
  end

  describe "GET /audit/resources/:item_type/:item_id" do
    it "scopes to the current tenant on the resource timeline" do
      RailsAuditLog::AuditLogEntry.create!(
        event: "create", item_type: "Post", item_id: 1, tenant_id: "acme"
      )
      RailsAuditLog::AuditLogEntry.create!(
        event: "update", item_type: "Post", item_id: 1, tenant_id: "globex"
      )

      RailsAuditLog.current_tenant { "acme" }
      get "/audit/resources/Post/1"
      expect(response.body).to include("create")
      expect(response.body).not_to include("ral-badge--update")
    end
  end
end

RSpec.describe "RailsAuditLog.acts_as_tenant!" do
  after { RailsAuditLog.instance_variable_set(:@current_tenant, nil) }

  it "raises when ActsAsTenant is not loaded" do
    hide_const("ActsAsTenant") if defined?(ActsAsTenant)
    expect { RailsAuditLog.acts_as_tenant! }.to raise_error(RuntimeError, /acts_as_tenant/)
  end

  it "wires current_tenant to ActsAsTenant.current_tenant.id" do
    tenant = double("Tenant", id: 42)
    fake_aat = Module.new { def self.current_tenant = nil }
    stub_const("ActsAsTenant", fake_aat)
    allow(ActsAsTenant).to receive(:current_tenant).and_return(tenant)

    RailsAuditLog.acts_as_tenant!

    expect(RailsAuditLog.current_tenant.call).to eq(42)
  end

  it "returns nil when ActsAsTenant.current_tenant is nil" do
    fake_aat = Module.new { def self.current_tenant = nil }
    stub_const("ActsAsTenant", fake_aat)
    allow(ActsAsTenant).to receive(:current_tenant).and_return(nil)

    RailsAuditLog.acts_as_tenant!

    expect(RailsAuditLog.current_tenant.call).to be_nil
  end
end
