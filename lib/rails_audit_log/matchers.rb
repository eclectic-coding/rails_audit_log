module RailsAuditLog
  # RSpec matchers for asserting audit log behaviour.
  #
  # == Setup
  #
  #   # spec/rails_helper.rb
  #   require "rails_audit_log/matchers"
  #
  #   RSpec.configure do |config|
  #     config.include RailsAuditLog::Matchers
  #   end
  #
  # == Usage
  #
  #   # Assert a record already has an entry
  #   expect(post).to have_audit_log_entry(:update).touching(:title)
  #
  #   # Assert a block creates a new entry
  #   expect { post.update!(title: "New") }.to create_audit_log_entry(event: :update, touching: :title)
  module Matchers
    # Returns a matcher that asserts the record has at least one matching
    # {AuditLogEntry}.
    #
    # @param event [Symbol, String, nil] optional event filter
    #   (<tt>:create</tt>, <tt>:update</tt>, or <tt>:destroy</tt>)
    # @return [HaveAuditLogEntry]
    # @example
    #   expect(post).to have_audit_log_entry
    #   expect(post).to have_audit_log_entry(:update)
    #   expect(post).to have_audit_log_entry(:update).touching(:title)
    def have_audit_log_entry(event = nil)
      HaveAuditLogEntry.new(event)
    end

    # Returns a matcher that asserts the block creates at least one new
    # {AuditLogEntry} matching the given filters.
    #
    # @param event [Symbol, String, nil] optional event filter
    # @param touching [Symbol, String, nil] optional attribute filter
    # @return [CreateAuditLogEntry]
    # @example
    #   expect { post.update!(title: "x") }.to create_audit_log_entry(event: :update)
    #   expect { post.update!(title: "x") }.to create_audit_log_entry(touching: :title)
    def create_audit_log_entry(event: nil, touching: nil)
      CreateAuditLogEntry.new(event: event, touching: touching)
    end

    # RSpec matcher — asserts that a record already has a matching entry.
    class HaveAuditLogEntry
      def initialize(event)
        @event    = event
        @touching = nil
      end

      # Chains an attribute filter onto the matcher.
      #
      # @param attribute [Symbol, String]
      # @return [self]
      def touching(attribute)
        @touching = attribute
        self
      end

      # @api private
      def matches?(record)
        @record = record
        scope = record.audit_log_entries
        scope = scope.where(event: @event.to_s) if @event
        scope = scope.touching(@touching)       if @touching
        scope.exists?
      end

      # @api private
      def failure_message
        "expected #{@record.class}##{@record.id} to have an audit log entry#{qualifier}"
      end

      # @api private
      def failure_message_when_negated
        "expected #{@record.class}##{@record.id} not to have an audit log entry#{qualifier}"
      end

      # @api private
      def description
        "have an audit log entry#{qualifier}"
      end

      private

      def qualifier
        parts = []
        parts << " with event '#{@event}'" if @event
        parts << " touching '#{@touching}'" if @touching
        parts.join
      end
    end

    # RSpec matcher — asserts that a block creates a new matching entry.
    class CreateAuditLogEntry
      def initialize(event:, touching:)
        @event    = event
        @touching = touching
      end

      # Chains an attribute filter onto the matcher.
      #
      # @param attribute [Symbol, String]
      # @return [self]
      def touching(attribute)
        @touching = attribute
        self
      end

      # @api private
      def supports_block_expectations?
        true
      end

      # @api private
      def matches?(block)
        @before = matching_scope.count
        block.call
        @after = matching_scope.count
        @after > @before
      end

      # @api private
      def failure_message
        "expected block to create an audit log entry#{qualifier}, but none was created"
      end

      # @api private
      def failure_message_when_negated
        "expected block not to create an audit log entry#{qualifier}, but one was created"
      end

      # @api private
      def description
        "create an audit log entry#{qualifier}"
      end

      private

      def matching_scope
        scope = RailsAuditLog::AuditLogEntry.all
        scope = scope.where(event: @event.to_s) if @event
        scope = scope.touching(@touching)       if @touching
        scope
      end

      def qualifier
        parts = []
        parts << " with event '#{@event}'" if @event
        parts << " touching '#{@touching}'" if @touching
        parts.join
      end
    end
  end
end
