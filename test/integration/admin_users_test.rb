require "test_helper"

# #41 ADM-01/02 รายชื่อผู้ใช้ทั้งหมดและหน้ารายละเอียด · #38 SUSP-01/07/08 ระงับ/ยกเลิกระงับ
class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @somchai = create_bidder(username: "somchai", fullname: "สมชาย ใจดี")
    @somsri = create_approved_bidder(username: "somsri", fullname: "สมศรี รักงาน", admin: @admin)
    sign_in(@admin)
  end

  # ---- รายชื่อ (ADM-01)
  test "ADM-01: แสดงผู้ใช้ทั้งหมด (ไม่รวม admin) พร้อมสถานะ" do
    get admin_users_path
    assert_response :success
    assert_select "td a", "somchai"
    assert_select "td a", "somsri"
    assert_select "td a", { text: @admin.username, count: 0 }
    assert_select ".ui-badge", "รอกรอกทรัพย์สิน"
    assert_select ".ui-badge", "ผ่าน"
  end

  test "ADM-01: ค้นหาและกรอง คงค่าตัวกรองในฟอร์ม" do
    get admin_users_path, params: { q: "รักงาน" }
    assert_select "td a", "somsri"
    assert_select "td a", { text: "somchai", count: 0 }
    assert_select "input[name='q'][value='รักงาน']"

    get admin_users_path, params: { qualification_status: "awaiting_assets" }
    assert_select "td a", "somchai"
    assert_select "td a", { text: "somsri", count: 0 }
    assert_select "select[name='qualification_status'] option[selected][value='awaiting_assets']"

    @somchai.suspend!(by: @admin, reason: "ทดสอบ")
    get admin_users_path, params: { suspension: "suspended" }
    assert_select "td a", "somchai"
    assert_select "td a", { text: "somsri", count: 0 }

    get admin_users_path, params: { q: "ไม่มีใครชื่อนี้" }
    assert_select ".ui-table__message", "ไม่พบผู้ใช้ตามเงื่อนไข"
  end

  test "ADM-01: แบ่งหน้าและคงตัวกรองเมื่อเปลี่ยนหน้า" do
    (Admin::UsersController::PER_PAGE + 1).times { |i| create_bidder(username: "page_user_#{i}") }
    get admin_users_path, params: { q: "page_user" }
    assert_select "td a", count: Admin::UsersController::PER_PAGE
    assert_select "a[rel='next'][href*='q=page_user'][href*='page=2']"

    get admin_users_path, params: { q: "page_user", page: 2 }
    assert_select "td a", count: 1
    assert_select ".ui-pagination__info", "หน้า 2 จาก 2"
  end

  # ---- รายละเอียด (ADM-02, QUAL-14)
  test "ADM-02/QUAL-14: หน้ารายละเอียดแสดงข้อมูล เพดานราคา ประวัติทุกรอบ และปุ่มจัดการ" do
    QualificationSubmission.submit(@somchai, [ { name: "บ้าน", value: "100" } ]).reject!(@admin, "รอบแรกไม่ผ่าน")
    QualificationSubmission.submit(@somchai.reload, [ { name: "บ้าน", value: "200" } ])

    get admin_user_path(@somchai)
    assert_response :success
    assert_select "h1", "somchai"
    assert_select "td", /รอบแรกไม่ผ่าน/
    assert_select ".ui-badge", "ล่าสุด"
    assert_select "form[action='#{admin_user_password_reset_path(@somchai)}']"
    assert_select "a[href='#{new_admin_user_suspension_path(@somchai)}']"

    get admin_user_path(@somsri)
    assert_select "dd", "5,000 บาท"
  end

  test "ADM-02: หน้ารายละเอียดใช้กับบัญชี admin ไม่ได้" do
    get admin_user_path(@admin)
    assert_response :not_found
  end

  test "AUTH-12: รีเซ็ตรหัสผ่านผู้ใช้จากหน้ารายละเอียด แล้วกลับหน้าผู้ใช้ได้" do
    post admin_user_password_reset_path(@somsri)
    assert_response :success
    assert_select "a[href='#{admin_user_path(@somsri)}']"
  end

  # ---- ระงับ (SUSP)
  test "SUSP-01: ระงับพร้อมเหตุผลผ่านฟอร์มที่มีขั้นยืนยัน → session ของผู้ใช้หมดผล" do
    get new_admin_user_suspension_path(@somsri)
    assert_select "form[data-turbo-confirm]"

    post admin_user_suspension_path(@somsri), params: { suspension: { reason: "ทุจริต" } }
    assert_redirected_to admin_user_path(@somsri)
    assert @somsri.reload.suspended?
    assert_equal "ทุจริต", @somsri.suspension_events.last.reason
    assert_equal "user.suspend", AuditLog.last.action

    follow_redirect!
    assert_select ".ui-badge", "ถูกระงับ"
    assert_select "td", "ทุจริต"
  end

  test "SUSP-01: เหตุผลว่างไม่ระงับ และแสดง error ใต้ช่อง" do
    post admin_user_suspension_path(@somsri), params: { suspension: { reason: "" } }
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /ต้องระบุเหตุผล/
    assert_not @somsri.reload.suspended?
  end

  test "SUSP-07/08: ยกเลิกระงับพร้อมเหตุผล → กลับสถานะเดิม และมีประวัติทั้งสองครั้ง" do
    @somsri.suspend!(by: @admin, reason: "ตรวจสอบ")
    delete admin_user_suspension_path(@somsri), params: { suspension: { reason: "ไม่พบความผิด" } }
    assert_redirected_to admin_user_path(@somsri)
    assert_not @somsri.reload.suspended?
    assert @somsri.qualified?
    assert_equal %w[unsuspend suspend], @somsri.suspension_events.newest_first.map(&:action)
  end

  test "SUSP-08: ยกเลิกระงับโดยไม่มีเหตุผลไม่สำเร็จ" do
    @somsri.suspend!(by: @admin, reason: "ตรวจสอบ")
    delete admin_user_suspension_path(@somsri), params: { suspension: { reason: " " } }
    assert_redirected_to admin_user_path(@somsri)
    assert_match(/ไม่สำเร็จ/, flash[:alert])
    assert @somsri.reload.suspended?
  end

  test "SUSP-09: route ระงับใช้กับบัญชี admin ไม่ได้" do
    other = create_admin
    post admin_user_suspension_path(other), params: { suspension: { reason: "x" } }
    assert_response :not_found
  end

  test "SUSP-02: ผู้ใช้ที่ถูกระงับขณะ login อยู่ หมดผลทันที" do
    delete logout_path
    sign_in(@somsri)
    get root_path
    assert_response :success
    @somsri.suspend!(by: @admin, reason: "ทันที")
    get root_path
    assert_redirected_to login_path
  end

  test "AUTH-10: ผู้ประมูลเข้าหน้ารายชื่อหรือสั่งระงับไม่ได้" do
    delete logout_path
    sign_in(@somsri)
    get admin_users_path
    assert_response :forbidden
    post admin_user_suspension_path(@somchai), params: { suspension: { reason: "x" } }
    assert_response :forbidden
    assert_not @somchai.reload.suspended?
  end
end
