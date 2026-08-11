Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Commerce7 activation/deactivation webhooks. The secret token is embedded in the
  # path itself (rather than a header) since we don't yet know whether Commerce7's
  # partner portal lets us configure custom headers on these URLs.
  namespace :commerce7 do
    post "activate/:token", to: "activations#create", as: :activate
    post "deactivate/:token", to: "deactivations#create", as: :deactivate
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
