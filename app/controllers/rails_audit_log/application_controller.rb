module RailsAuditLog
  class ApplicationController < ActionController::Base
    include Pagy::Method

    protect_from_forgery with: :exception
  end
end
