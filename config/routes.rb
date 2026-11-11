Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ---- ผู้ใช้ (bidder)
  root "home#show"

  # หน้าตัวอย่าง component ของ Design System ไว้ดูบนมือถือ/เดสก์ท็อป (เฉพาะ development/test)
  match "styleguide", to: "styleguide#show", via: %i[get post patch delete] if Rails.env.local?
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  resource :registration, only: %i[new create]
  # หน้าสถานะคุณสมบัติ + ส่ง/แก้ทรัพย์สิน (QUAL-02/04/05/06/09)
  resource :qualification, only: %i[show create]

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
    # ผู้ใช้ทั้งหมด + รายละเอียด (ADM-01/02) · ระงับ/ยกเลิกระงับ (SUSP-01/07)
    resources :users, only: %i[index show] do
      resource :password_reset, only: :create
      resource :suspension, only: %i[new create destroy]
    end
    # คิวตรวจคุณสมบัติ (QUAL-07/08)
    resources :qualification_submissions, only: %i[index show] do
      member do
        post :approve
        post :reject
      end
    end
    # ประวัติการกระทำของ admin (NFR-17/18) ดูได้อย่างเดียว
    resources :audit_logs, only: :index

    # ข้อมูลหลัก (#43-#51)
    resources :auction_methods, only: %i[index new create] do
      member do
        patch :enable
        patch :disable
      end
    end
    resources :rooms, except: :show do
      patch :archive, on: :member
    end
    resources :items do
      member do
        patch :approve
        patch :archive
      end
      resources :images, only: :destroy, controller: "item_images"
    end

    # การประมูล (EVT-01): ไม่มีหน้า show แยก ดู/แก้ที่หน้า edit · ยกเลิกเป็น PATCH แยก (EVT-08)
    resources :auction_events, path: "auctions", except: :show do
      patch :cancel, on: :member
    end
  end
end
