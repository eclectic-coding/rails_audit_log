module RailsAuditLog
  module ApplicationHelper
    def dashboard_stylesheets
      dir = RailsAuditLog::Engine.root.join("app/assets/stylesheets/rails_audit_log")
      dir.glob("_*.css").sort.map do |file|
        stylesheet_link_tag("rails_audit_log/#{file.basename}", media: "all")
      end.join("\n").html_safe
    end
  end
end
