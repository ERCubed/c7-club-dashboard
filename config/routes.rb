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

    # Tab Menu extension on Order Detail: a per-customer club membership summary.
    # Commerce7 has no Customer Detail placement, so this is the nearest fit.
    get "order-detail-card", to: "order_detail_card#show", as: :order_detail_card

    # Settings tab App Extension page (registered in Commerce7's Developer
    # Center as the app's "Settings tab iFrame URL") — lets staff assign a
    # color per club tier, persisted per tenant.
    get "settings", to: "settings#show", as: :settings
    patch "settings", to: "settings#update"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
