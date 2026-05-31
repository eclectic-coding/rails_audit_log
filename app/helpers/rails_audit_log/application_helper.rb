module RailsAuditLog
  # @api private
  module ApplicationHelper
    def format_diff_value(value)
      return "—" if value.nil?
      return "#{value["type"]} ##{value["id"]}" if value.is_a?(Hash)

      value.inspect
    end

    def dashboard_stylesheets
      dir = RailsAuditLog::Engine.root.join("app/assets/stylesheets/rails_audit_log")
      dir.glob("_*.css").sort.map do |file|
        stylesheet_link_tag("rails_audit_log/#{file.basename}", media: "all")
      end.join("\n").html_safe
    end
  end
end
