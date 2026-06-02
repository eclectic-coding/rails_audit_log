class AddTenantIdToAuditLogEntries < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :audit_log_entries, :tenant_id, :string
    add_index  :audit_log_entries, :tenant_id
  end
end