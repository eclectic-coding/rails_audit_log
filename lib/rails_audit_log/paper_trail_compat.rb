module RailsAuditLog
  # Opt-in compatibility shim for gradual migration from PaperTrail.
  # Include alongside RailsAuditLog::Auditable to keep PaperTrail's
  # familiar API while your codebase migrates.
  #
  # @example
  #   class Article < ApplicationRecord
  #     include RailsAuditLog::Auditable
  #     include RailsAuditLog::PaperTrailCompat
  #   end
  #
  #   article.versions                         # audit_log_entries, oldest-first
  #   article.paper_trail.version              # most recent AuditLogEntry
  #   article.paper_trail.previous_version     # reconstructed previous state
  #   article.paper_trail.originator           # whodunnit_snapshot string
  #   article.paper_trail.version_at(1.week.ago) # time-travel reconstruction
  module PaperTrailCompat
    extend ActiveSupport::Concern

    included do
      has_many :versions,
               -> { order(created_at: :asc, id: :asc) },
               class_name: "RailsAuditLog::AuditLogEntry",
               as:         :item,
               dependent:  :destroy
    end

    # Returns a proxy that exposes PaperTrail's instance-level API.
    def paper_trail
      @paper_trail_proxy ||= Proxy.new(self)
    end

    # Proxy providing the PaperTrail instance API surface.
    class Proxy
      def initialize(record)
        @record = record
      end

      # The most recent audit entry for the record.
      def version
        @record.audit_log_entries.order(id: :desc).first
      end

      # Reconstructed record state before the most recent change.
      # Returns nil for newly created records.
      def previous_version
        version&.reify
      end

      # Display name of the actor who made the most recent change.
      def originator
        version&.whodunnit_snapshot
      end

      # Reconstructs the record's state as it was at the given timestamp.
      # Delegates to RailsAuditLog.version_at.
      def version_at(timestamp)
        RailsAuditLog.version_at(@record, timestamp)
      end
    end
  end
end
