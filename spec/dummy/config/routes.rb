Rails.application.routes.draw do
  mount RailsAuditLog::Engine, at: "/audit"

  root to: redirect("/audit")
  resources :posts, only: [:create]
end
