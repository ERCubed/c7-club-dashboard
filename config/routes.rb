Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Commerce7 activation/deactivation webhooks. Per Commerce7's docs, install/uninstall
  # URLs can be secured with HTTP Basic Auth credentials we configure in their dashboard.
  namespace :commerce7 do
    post "activate", to: "activations#create", as: :activate
    post "deactivate", to: "deactivations#create", as: :deactivate

    # App Extension page for the Reports > Club Report placement.
    get "dashboard", to: "dashboard#show", as: :dashboard
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
