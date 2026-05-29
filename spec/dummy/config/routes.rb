Rails.application.routes.draw do
  root to: redirect("/audit_entries")
  resources :audit_entries, only: [:index]
  resources :posts, only: [:create]
end
