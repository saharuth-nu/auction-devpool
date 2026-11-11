require "test_helper"

# #27 AUTH-10, NFR-08: ปฏิเสธโดยค่าเริ่มต้น
class DenyByDefaultProbeController < ApplicationController
  # ตั้งใจไม่ประกาศ allow_roles
  def index = render(plain: "ok")
end

class BidderOnlyProbeController < ApplicationController
  allow_roles :bidder
  def index = render(plain: "ok")
end

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @bidder = create_bidder
    @admin = create_admin
  end

  test "ยังไม่ login: หน้าผู้ใช้ไป login ผู้ใช้ หน้า admin ไป login admin" do
    get root_path
    assert_redirected_to login_path
    get profile_path
    assert_redirected_to login_path
    get admin_root_path
    assert_redirected_to admin_login_path
    get admin_admins_path
    assert_redirected_to admin_login_path
  end

  test "ยังไม่ login: request แก้ข้อมูลฝั่ง admin ถูกปฏิเสธ" do
    post admin_admins_path, params: { user: { username: "hacker01", password: "password123", password_confirmation: "password123" } }
    assert_redirected_to admin_login_path
    assert_nil User.find_by(username: "hacker01")
  end

  test "AUTH-10: ผู้ใช้เข้าหน้า admin ทุกหน้าไม่ได้ (403)" do
    sign_in(@bidder)
    get admin_root_path
    assert_response :forbidden
    get admin_admins_path
    assert_response :forbidden
    get new_admin_admin_path
    assert_response :forbidden
  end

  test "AUTH-10: ผู้ใช้สั่งการกระทำฝั่ง admin ตรงๆ ไม่ได้ และข้อมูลไม่เปลี่ยน" do
    target = create_admin
    sign_in(@bidder)

    post admin_admins_path, params: { user: { username: "hacker01", password: "password123", password_confirmation: "password123" } }
    assert_response :forbidden
    assert_nil User.find_by(username: "hacker01")

    post admin_admin_password_reset_path(target)
    assert_response :forbidden
    assert_not target.reload.must_change_password?

    post admin_admin_disablement_path(target), params: { disablement: { reason: "x" } }
    assert_response :forbidden
    assert_not target.reload.disabled?
  end

  test "admin เข้าหน้าแรกของผู้ใช้แล้วถูกพาไปหน้า admin" do
    sign_in(@admin)
    get root_path
    assert_redirected_to admin_root_path
  end

  test "ทั้งสองบทบาทเข้าโปรไฟล์ของตนเองได้" do
    sign_in(@bidder)
    get profile_path
    assert_response :success
    delete logout_path
    sign_in(@admin)
    get profile_path
    assert_response :success
  end

  test "NFR-08: controller ที่ไม่ประกาศ allow_roles ถูกปฏิเสธ (403) แม้ login แล้ว" do
    with_probe_routes do
      sign_in(@admin) # with_routing สร้าง session ใหม่ ต้อง login ภายใน block
      get "/probe/deny"
      assert_response :forbidden
    end
  end

  test "NFR-08: allow_roles จำกัดตามบทบาท" do
    with_probe_routes do
      sign_in(@bidder)
      get "/probe/bidder"
      assert_response :success

      delete logout_path
      sign_in(@admin)
      get "/probe/bidder"
      assert_response :forbidden
    end
  end

  test "NFR-08: ไม่ login ต้อง login ก่อนแม้ controller ไม่ประกาศ allow_roles" do
    with_probe_routes do
      get "/probe/deny"
      assert_redirected_to login_path
    end
  end

  # ---- บังคับเปลี่ยนรหัสผ่าน (AUTH-13) ต้องไม่ยอมให้ข้ามไปหน้าอื่น
  test "AUTH-13: บัญชีที่ต้องเปลี่ยนรหัสผ่านถูกพาไปหน้าเปลี่ยนรหัสทุกหน้า ยกเว้น logout" do
    @bidder.update!(must_change_password: true)
    sign_in(@bidder)
    assert_redirected_to forced_password_path

    [ root_path, profile_path, edit_password_path ].each do |path|
      get path
      assert_redirected_to forced_password_path, "#{path} ควรถูกบังคับ"
    end

    get forced_password_path
    assert_response :success

    assert_difference -> { Session.count }, -1 do
      delete logout_path
    end
  end

  test "AUTH-13: บัญชีที่ไม่ต้องเปลี่ยนรหัสเข้าหน้าบังคับแล้วถูกส่งกลับ" do
    sign_in(@bidder)
    get forced_password_path
    assert_redirected_to root_path
  end

  private

  # route ชั่วคราวสำหรับ controller สมมติ (ต้องมี named route ที่ layout ใช้ด้วย)
  def with_probe_routes(&block)
    with_routing do |set|
      set.draw do
        root "home#show"
        get "login", to: "sessions#new"
        post "login", to: "sessions#create"
        delete "logout", to: "sessions#destroy"
        resource :profile, only: :show
        resource :forced_password, only: :show
        namespace :admin do
          root "dashboard#show"
          get "login", to: "sessions#new"
          post "login", to: "sessions#create"
        end
        get "probe/deny", to: "deny_by_default_probe#index"
        get "probe/bidder", to: "bidder_only_probe#index"
      end
      block.call
    end
  end
end
