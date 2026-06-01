# Data migration: re-encrypts existing plain-text audit entries for every
# model listed in ENCRYPTED_MODELS.
#
# == Before running
#
# 1. Add the class names of every model that uses `audit_log encrypt: true`
#    (or that will be covered by `RailsAuditLog.encrypt = true`) to the
#    ENCRYPTED_MODELS constant below.
#
# 2. Ensure ActiveRecord::Encryption is configured with your production keys
#    (config/initializers/rails_audit_log_encryption.rb).
#
# 3. Run: bin/rails db:migrate
#
# Entries that are already encrypted (detected by the internal envelope format)
# are skipped automatically — the migration is safe to re-run.
#
# This migration is irreversible.

class EncryptRailsAuditLogEntries < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  BATCH_SIZE        = 500
  ENCRYPTION_MARKER = RailsAuditLog::AuditLogEntry::ENCRYPTION_MARKER

  # Add the class names of every model whose audit entries should be encrypted:
  ENCRYPTED_MODELS = %w[
    # Post
    # Payment
    # User
  ].freeze

  # Isolated AR class — avoids coupling to host-app model overrides.
  class Entry < ActiveRecord::Base   # @api private
    self.table_name = "audit_log_entries"
  end

  def up
    if ENCRYPTED_MODELS.empty?
      say "  No ENCRYPTED_MODELS configured — nothing to re-encrypt. " \
          "Edit the migration and add your model class names, then re-run."
      return
    end

    ENCRYPTED_MODELS.each do |model_name|
      say_with_time "Re-encrypting audit entries for #{model_name}" do
        re_encrypt_for(model_name)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse encryption migration — decryption would require the original " \
          "keys and there is no way to distinguish re-encrypted rows from native ones."
  end

  private

  def re_encrypt_for(item_type)
    count = 0
    Entry.where(item_type: item_type).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each do |entry|
        changes = entry.read_attribute(:object_changes)
        object  = entry.read_attribute(:object)

        updates = {}
        updates[:object_changes] = encrypt(changes) if changes && !encrypted?(changes)
        updates[:object]         = encrypt(object)  if object  && !encrypted?(object)
        next if updates.empty?

        entry.update_columns(updates)
        count += 1
      end
    end
    count
  end

  def encrypted?(value)
    value.is_a?(Hash) && value.keys == [ENCRYPTION_MARKER]
  end

  def encrypt(value)
    ciphertext = ActiveRecord::Encryption.encryptor.encrypt(value.to_json)
    { ENCRYPTION_MARKER => ciphertext }
  end
end