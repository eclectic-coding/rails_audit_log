class CreateAuditLogEntries < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :audit_log_entries do |t|
      t.string  :event,      null: false
      t.string  :item_type,  null: false
      t.bigint  :item_id,    null: false
      t.json    :object_changes
      t.json    :object
      t.json    :metadata
      t.string  :reason
      t.string  :actor_type
      t.bigint  :actor_id
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :audit_log_entries, [:item_type, :item_id]
    add_index :audit_log_entries, [:actor_type, :actor_id]
    add_index :audit_log_entries, :event
    add_index :audit_log_entries, :created_at
  end
end