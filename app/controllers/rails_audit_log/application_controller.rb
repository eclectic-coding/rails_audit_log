module RailsAuditLog
  # @api private
  class ApplicationController < ActionController::Base
    include Pagy::Method

    protect_from_forgery with: :exception
    before_action :authenticate!

    private

    def authenticate!
      return unless (auth = RailsAuditLog.authenticate)

      instance_exec(self, &auth) || request_http_basic_authentication("Audit Log")
    end
  end
end
