RailsAuditLog::Engine.routes.draw do
  root to: "audit_log_entries#index"
  resources :audit_log_entries, only: [:index, :show] do
    collection do
      get "resource/:item_type/:item_id", to: "audit_log_entries#resource", as: :resource
    end
  end
end
