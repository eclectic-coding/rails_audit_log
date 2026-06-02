require "rails_helper"

RSpec.describe "tenant capture" do
  after do
    RailsAuditLog.instance_variable_set(:@current_tenant, nil)
    Post._audit_log_tenant = nil
  end

  describe "RailsAuditLog.current_tenant global resolver" do
    it "stores nil when not configured" do
      expect(RailsAuditLog.current_tenant).to be_nil
    end

    it "stores and returns the configured block" do
      RailsAuditLog.current_tenant { "acme" }
      expect(RailsAuditLog.current_tenant).to be_a(Proc)
    end

    it "captures the resolved tenant_id on create" do
      RailsAuditLog.current_tenant { "acme" }
      post = Post.create!(title: "Hello")
      entry = post.audit_log_entries.last
      expect(entry.tenant_id).to eq("acme")
    end

    it "captures the resolved tenant_id on update" do
      RailsAuditLog.current_tenant { "acme" }
      post = Post.create!(title: "Hello")
      post.update!(title: "World")
      entry = post.audit_log_entries.order(:id).last
      expect(entry.tenant_id).to eq("acme")
    end

    it "captures the resolved tenant_id on destroy" do
      RailsAuditLog.current_tenant { "acme" }
      post = Post.create!(title: "Hello")
      post.destroy!
      entry = RailsAuditLog::AuditLogEntry.where(item_type: "Post", item_id: post.id).last
      expect(entry.tenant_id).to eq("acme")
    end

    it "stores nil when resolver returns nil" do
      RailsAuditLog.current_tenant { nil }
      post = Post.create!(title: "Hello")
      expect(post.audit_log_entries.last.tenant_id).to be_nil
    end
  end

  describe "audit_log tenant: per-model override" do
    around do |example|
      Post.audit_log tenant: -> { "per-model-tenant" }
      example.run
      Post._audit_log_tenant = nil
    end

    it "captures the per-model tenant_id on create" do
      post = Post.create!(title: "Hello")
      expect(post.audit_log_entries.last.tenant_id).to eq("per-model-tenant")
    end

    it "takes precedence over the global resolver" do
      RailsAuditLog.current_tenant { "global-tenant" }
      post = Post.create!(title: "Hello")
      expect(post.audit_log_entries.last.tenant_id).to eq("per-model-tenant")
    end
  end

  describe "no resolver configured" do
    it "stores nil for tenant_id" do
      post = Post.create!(title: "Hello")
      expect(post.audit_log_entries.last.tenant_id).to be_nil
    end
  end
end
