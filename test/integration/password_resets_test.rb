require "test_helper"

# #31 AUTH-12/13/14
class PasswordResetsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @bidder = create_bidder
    @other_admin = create_admin
    sign_in(@admin)
  end

  def temporary_password_from_page
    response.body[%r{<code class="ui-secret">([^<]+)</code>}, 1]
  end

  test "AUTH-12: admin รีเซ็ตรหัสผ่านผู้ใช้ได้ แสดงรหัสชั่วคราวครั้งเดียว" do
    post admin_user_password_reset_path(@bidder)
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]

    temporary = temporary_password_from_page
    assert_equal User::TEMPORARY_PASSWORD_LENGTH, temporary.length
    assert_match(/\A[A-Za-z0-9]+\z/, temporary)

    @bidder.reload
    assert @bidder.must_change_password?
    assert @bidder.authenticate(temporary)
    assert_not @bidder.authenticate(DEFAULT_PASSWORD)
  end

  test "AUTH-12: admin รีเซ็ตรหัสผ่าน admin คนอื่นได้" do
    post admin_admin_password_reset_path(@other_admin)
    assert_response :success
    assert @other_admin.reload.must_change_password?
  end

  test "รีเซ็ตแล้ว session ที่ใช้อยู่ของบัญชีนั้นถูกลบ" do
    @bidder.sessions.create!
    post admin_user_password_reset_path(@bidder)
    assert_equal 0, @bidder.sessions.count
  end

  test "รหัสชั่วคราวไม่ถูกเก็บใน flash/session ของ admin และไม่อยู่ในหน้าถัดไป" do
    post admin_user_password_reset_path(@bidder)
    temporary = temporary_password_from_page
    assert_nil flash[:notice]
    assert_nil flash[:alert]
    get admin_admins_path
    assert_not_includes response.body, temporary
  end

  test "AUTH-14: รีเซ็ตรหัสผ่านตัวเองไม่ได้ และรหัสไม่เปลี่ยน" do
    digest = @admin.password_digest
    post admin_admin_password_reset_path(@admin)
    assert_redirected_to admin_admins_path
    follow_redirect!
    assert_select ".ui-alert--error", /รีเซ็ตรหัสผ่านของตัวเองไม่ได้/
    @admin.reload
    assert_equal digest, @admin.password_digest
    assert_not @admin.must_change_password?
  end

  test "ผู้ประมูลรีเซ็ตรหัสของใครไม่ได้" do
    delete logout_path
    sign_in(@bidder)
    post admin_admin_password_reset_path(@other_admin)
    assert_response :forbidden
    assert_not @other_admin.reload.must_change_password?
  end

  test "route ผู้ใช้ใช้กับ admin ไม่ได้ และกลับกัน (ไม่พบ)" do
    post admin_user_password_reset_path(@other_admin)
    assert_response :not_found
    post admin_admin_password_reset_path(@bidder)
    assert_response :not_found
  end

  # ---- ผู้ถูกรีเซ็ต: login → บังคับเปลี่ยน (AUTH-13)
  test "AUTH-13: login ด้วยรหัสชั่วคราวแล้วต้องตั้งรหัสใหม่ก่อนใช้งาน" do
    post admin_user_password_reset_path(@bidder)
    temporary = temporary_password_from_page
    delete logout_path

    post login_path, params: { login: { username: @bidder.username, password: temporary } }
    assert_redirected_to forced_password_path
    get root_path
    assert_redirected_to forced_password_path

    patch forced_password_path, params: { user: { password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_redirected_to root_path
    assert_not @bidder.reload.must_change_password?
    get root_path
    assert_response :success

    delete logout_path
    post login_path, params: { login: { username: @bidder.username, password: "brandnew123" } }
    assert_redirected_to root_path
  end

  test "AUTH-13: รหัสใหม่ต้องไม่ซ้ำรหัสชั่วคราว" do
    post admin_user_password_reset_path(@bidder)
    temporary = temporary_password_from_page
    delete logout_path
    post login_path, params: { login: { username: @bidder.username, password: temporary } }

    patch forced_password_path, params: { user: { password: temporary, password_confirmation: temporary } }
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /ไม่ซ้ำ/
    assert @bidder.reload.must_change_password?
  end

  test "AUTH-13: รหัสใหม่ต้องผ่านกฎ AUTH-06 (สั้นเกิน/ยืนยันไม่ตรง) และยังถูกบังคับอยู่" do
    post admin_user_password_reset_path(@bidder)
    temporary = temporary_password_from_page
    delete logout_path
    post login_path, params: { login: { username: @bidder.username, password: temporary } }

    patch forced_password_path, params: { user: { password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
    patch forced_password_path, params: { user: { password: "brandnew123", password_confirmation: "different123" } }
    assert_response :unprocessable_entity
    assert @bidder.reload.must_change_password?
    get root_path
    assert_redirected_to forced_password_path
  end

  test "AUTH-13: admin ที่ถูกรีเซ็ตต้องเปลี่ยนรหัสก่อนเข้าหน้า admin" do
    post admin_admin_password_reset_path(@other_admin)
    temporary = temporary_password_from_page
    delete logout_path

    post admin_login_path, params: { login: { username: @other_admin.username, password: temporary } }
    assert_redirected_to forced_password_path
    get admin_admins_path
    assert_redirected_to forced_password_path

    patch forced_password_path, params: { user: { password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_redirected_to admin_root_path
  end
end
