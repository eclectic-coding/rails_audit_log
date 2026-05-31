require "yaml"
require "json"

# Data migration: copies PaperTrail `versions` rows to `audit_log_entries`.
#
# Column mapping:
#   versions.item_type        → audit_log_entries.item_type
#   versions.item_id          → audit_log_entries.item_id
#   versions.event            → audit_log_entries.event  (create/update/destroy only)
#   versions.object_changes   → audit_log_entries.object_changes  (YAML or JSON → JSON)
#   versions.object           → audit_log_entries.object           (YAML or JSON → JSON)
#   versions.whodunnit        → audit_log_entries.whodunnit_snapshot
#   versions.created_at       → audit_log_entries.created_at
#
# actor_type / actor_id are not populated — PaperTrail stores the actor
# only as a string (whodunnit), so polymorphic references cannot be inferred.
#
# This migration is irreversible.
class MigrateFromPaperTrail < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  BATCH_SIZE    = 1_000
  VALID_EVENTS  = %w[create update destroy].freeze

  # Isolated AR classes to avoid coupling to the host app's models.
  class Version < ActiveRecord::Base   # @api private
    self.table_name = "versions"
  end

  class AuditEntry < ActiveRecord::Base   # @api private
    self.table_name = "audit_log_entries"
  end

  def up
    unless table_exists?(:versions)
      say "  versions table not found — nothing to migrate."
      return
    end

    total     = Version.count
    migrated  = 0
    skipped   = 0

    say_with_time "Migrating #{total} PaperTrail versions → audit_log_entries" do
      Version.in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.filter_map do |v|
          next unless VALID_EVENTS.include?(v.event)

          {
            event:              v.event,
            item_type:          v.item_type,
            item_id:            v.item_id,
            object_changes:     parse_serialized(v.read_attribute_before_type_cast(:object_changes)),
            object:             parse_serialized(v.read_attribute_before_type_cast(:object)),
            whodunnit_snapshot: v.whodunnit,
            created_at:         v.created_at,
            updated_at:         v.created_at
          }
        end

        skipped  += batch.size - rows.size
        migrated += rows.size
        AuditEntry.insert_all(rows) if rows.any?
      end
    end

    say "  Migrated: #{migrated}  Skipped (unsupported event): #{skipped}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse PaperTrail migration — rows already written to audit_log_entries " \
          "cannot be reliably distinguished from native entries."
  end

  private

  # Parses a PaperTrail serialized column (YAML or JSON) and returns a Hash,
  # or nil if the value is blank or unparseable.
  def parse_serialized(value)
    return nil if value.nil? || value.to_s.strip.empty?

    begin
      parsed = JSON.parse(value)
      return parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      # fall through to YAML
    end

    begin
      parsed = YAML.safe_load(
        value,
        permitted_classes: [Symbol, Date, Time, DateTime, BigDecimal,
                             ActiveSupport::TimeWithZone, ActiveSupport::Duration]
      )
      parsed.is_a?(Hash) ? parsed : nil
    rescue StandardError
      nil
    end
  end
end