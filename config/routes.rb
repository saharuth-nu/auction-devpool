Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ---- ผู้ใช้ (bidder)
  root "home#show"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resource :registration, only: %i[new create]

  # ---- บัญชีของตนเอง (admin และผู้ใช้): โปรไฟล์, เปลี่ยนรหัสผ่าน, บังคับเปลี่ยนหลังถูกรีเซ็ต
  resource :profile, only: :show
  resource :password, only: %i[edit update], path: "profile/password"
  resource :forced_password, only: %i[show update], path: "password/required"

  # ---- admin
  namespace :admin do
    root "dashboard#show"
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"

    resources :admins, only: %i[index new create] do
      resource :disablement, only: %i[new create destroy]
      resource :password_reset, only: :create
    end
    resources :users, only: [] do
      resource :password_reset, only: :create
    end
  end
end
