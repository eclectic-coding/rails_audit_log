RailsAuditLog::Engine.routes.draw do
  root to: "audit_log_entries#index"
  resources :audit_log_entries, only: [:index, :show]
end
