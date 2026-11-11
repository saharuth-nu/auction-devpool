require "test_helper"

# #26 AUTH-01/02/11/16, NFR-07 · #39 SUSP-02 · ADM-08
class SessionsTest < ActionDispatch::IntegrationTest
  setup do
    @bidder = create_bidder
    @admin = create_admin
  end

  def login(username:, password: DEFAULT_PASSWORD, path: login_path)
    post path, params: { login: { username: username, password: password } }
  end

  test "AUTH-01/02: มีหน้า login แยกของ admin และผู้ใช้" do
    get login_path
    assert_response :success
    assert_select "h2", "เข้าสู่ระบบ"
    assert_select "a[href=?]", new_registration_path

    get admin_login_path
    assert_response :success
    assert_select "h2", "เข้าสู่ระบบผู้ดูแล"
    assert_select "a[href=?]", new_registration_path, count: 0
  end

  test "AUTH-02: ผู้ใช้ login สำเร็จแล้วไปหน้าแรกและมี session ฝั่ง server" do
    assert_difference -> { @bidder.sessions.count }, 1 do
      login(username: @bidder.username)
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "AUTH-01: admin login สำเร็จแล้วไปหน้า admin" do
    login(username: @admin.username, path: admin_login_path)
    assert_redirected_to admin_root_path
    follow_redirect!
    assert_response :success
  end

  test "username ไม่สนตัวพิมพ์ใหญ่/เล็ก" do
    login(username: @bidder.username.upcase)
    assert_redirected_to root_path
  end

  test "รหัสผ่านผิดหรือไม่มีบัญชี ตอบข้อความเดียวกันและไม่สร้าง session" do
    assert_no_difference -> { Session.count } do
      login(username: @bidder.username, password: "wrong-password")
      assert_response :unprocessable_entity
      assert_select ".ui-alert--error", /ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง/
      wrong = response.body[/ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง/]

      login(username: "nobody0000")
      assert_response :unprocessable_entity
      assert_equal wrong, response.body[/ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง/]
    end
  end

  test "AUTH-10: บัญชีผิดฝั่งถูกปฏิเสธเหมือนรหัสผ่านผิด (ไม่บอกว่ามีบัญชีอีกฝั่ง)" do
    assert_no_difference -> { Session.count } do
      login(username: @admin.username)                                  # admin ที่หน้า login ผู้ใช้
      assert_response :unprocessable_entity
      assert_select ".ui-alert--error", /ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง/

      login(username: @bidder.username, path: admin_login_path)         # ผู้ใช้ที่หน้า login admin
      assert_response :unprocessable_entity
      assert_select ".ui-alert--error", /ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง/
    end
  end

  test "AUTH-11: logout ลบ session และใช้ cookie เดิมซ้ำไม่ได้" do
    login(username: @bidder.username)
    old_cookie = cookies[:session_id]

    assert_difference -> { Session.count }, -1 do
      delete logout_path
    end
    assert_redirected_to login_path

    cookies[:session_id] = old_cookie
    get root_path
    assert_redirected_to login_path
  end

  test "logout ของ admin กลับหน้า login ของ admin" do
    login(username: @admin.username, path: admin_login_path)
    delete logout_path
    assert_redirected_to admin_login_path
  end

  test "AUTH-16: session หมดอายุหลัง 12 ชั่วโมง" do
    login(username: @bidder.username)
    get root_path
    assert_response :success

    travel 12.hours + 1.minute do
      get root_path
      assert_redirected_to login_path
    end
    assert_equal 0, @bidder.sessions.count
  end

  test "AUTH-16: cookie เป็น httponly" do
    login(username: @bidder.username)
    assert_match(/session_id=.*httponly/i, Array(response.headers["Set-Cookie"]).join("\n"))
  end

  test "NFR-07: login ผิดเกิน 10 ครั้งใน 3 นาทีถูกจำกัด" do
    10.times do
      login(username: @bidder.username, password: "wrong-password")
      assert_response :unprocessable_entity
    end
    login(username: @bidder.username, password: "wrong-password")
    assert_redirected_to login_path
    follow_redirect!
    assert_select ".ui-alert--error", /บ่อยเกินไป/

    # แม้รหัสผ่านถูกก็ถูกจำกัดในช่วงนั้น
    login(username: @bidder.username)
    assert_redirected_to login_path
  end

  test "login แล้วกลับไปหน้าที่ขอไว้เดิม (เฉพาะ path ภายในและฝั่งเดียวกับบทบาท)" do
    get profile_path
    assert_redirected_to login_path
    login(username: @bidder.username)
    assert_redirected_to profile_path
  end

  test "ปลายทางเดิมฝั่ง admin ไม่ถูกใช้กับผู้ใช้ที่ไม่ใช่ admin" do
    get admin_admins_path
    assert_redirected_to admin_login_path
    login(username: @bidder.username)           # ผู้ใช้ login ทางหน้าผู้ใช้ ปลายทางเดิมเป็นของ admin
    assert_redirected_to root_path
  end

  # ---- #39 SUSP-02
  test "SUSP-02: ผู้ถูกระงับ login ไม่ได้ (รหัสถูก) พร้อมข้อความระงับ" do
    @bidder.update!(suspended_at: Time.current)
    assert_no_difference -> { Session.count } do
      login(username: @bidder.username)
    end
    assert_response :unprocessable_entity
    assert_select ".ui-alert--error", /ถูกระงับ/
  end

  test "SUSP-02: ระงับขณะ login อยู่ → request ถัดไปหมดผลทันที" do
    login(username: @bidder.username)
    get root_path
    assert_response :success

    @bidder.update!(suspended_at: Time.current)
    get root_path
    assert_redirected_to login_path
    assert_equal 0, @bidder.sessions.count
  end

  test "SUSP-02: ยกเลิกระงับแล้ว login ได้อีก" do
    @bidder.update!(suspended_at: Time.current)
    @bidder.update!(suspended_at: nil)
    login(username: @bidder.username)
    assert_redirected_to root_path
  end

  test "ADM-08: admin ที่ถูกปิดใช้งาน login ไม่ได้ และ session ที่ใช้อยู่หมดผลทันที" do
    other = create_admin
    login(username: other.username, path: admin_login_path)
    get admin_root_path
    assert_response :success

    other.disable(by: @admin, reason: "ทดสอบ")
    get admin_root_path
    assert_redirected_to admin_login_path

    login(username: other.username, path: admin_login_path)
    assert_response :unprocessable_entity
    assert_select ".ui-alert--error", /ปิดใช้งาน/
  end
end
