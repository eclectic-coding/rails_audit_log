module RailsAuditLog
  # Include in +ApplicationController+ (or any controller) to automatically
  # set and clear the current actor for every request, so that audit entries
  # written during the request are tagged with the signed-in user.
  #
  # == Usage
  #
  #   class ApplicationController < ActionController::Base
  #     include RailsAuditLog::Controller
  #     audit_log_actor { current_user }
  #   end
  #
  # The block passed to {audit_log_actor} is evaluated in controller instance
  # context on every request via a +before_action+. The actor is cleared in an
  # +after_action+ so it never leaks between requests.
  #
  # Request metadata (+remote_ip+, +user_agent+) is captured automatically when
  # {RailsAuditLog.capture_request_metadata} is +true+.
  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :set_audit_log_actor
      after_action  :clear_audit_log_actor
      before_action :capture_audit_log_request_metadata
      after_action  :clear_audit_log_request_metadata
    end

    class_methods do
      # Registers a block that resolves the current actor for each request.
      # The block is evaluated in controller instance context, so any helper
      # method available to the controller (e.g. +current_user+) can be used.
      #
      # @yield block evaluated in controller context; should return the actor
      # @return [void]
      # @example
      #   audit_log_actor { current_user }
      #
      #   # With a one-argument lambda style (actor = the controller instance)
      #   audit_log_actor { |c| c.current_user }
      def audit_log_actor(&block)
        @audit_log_actor_block = block
      end

      # @api private
      def audit_log_actor_block
        @audit_log_actor_block
      end
    end

    private

    def set_audit_log_actor
      block = self.class.audit_log_actor_block
      RailsAuditLog.actor = instance_exec(&block) if block
    end

    def clear_audit_log_actor
      RailsAuditLog.actor = nil
    end

    def capture_audit_log_request_metadata
      return unless RailsAuditLog.capture_request_metadata

      RailsAuditLog.request_metadata = {
        "remote_ip" => request.remote_ip,
        "user_agent" => request.user_agent
      }.compact
    end

    def clear_audit_log_request_metadata
      return unless RailsAuditLog.capture_request_metadata

      RailsAuditLog.request_metadata = nil
    end
  end
end
