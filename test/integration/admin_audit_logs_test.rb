require "test_helper"

# #71 NFR-17/18 audit log: การกระทำของ admin ถูกบันทึก · หน้าดู/กรอง · ไม่มีทางแก้หรือลบ
class AdminAuditLogsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @other_admin = create_admin
    @user = create_bidder
    sign_in(@admin)
  end

  # ---- การกระทำในหน้าของ #30 #31 #42 ถูกบันทึก (NFR-17)
  test "NFR-17: สร้าง admin ลง log" do
    post admin_admins_path, params: { user: { username: "newadmin", password: "password123", password_confirmation: "password123" } }
    log = AuditLog.last
    assert_equal "admin.create", log.action
    assert_equal @admin, log.admin
    assert_equal User.find_by(username: "newadmin"), log.target
    assert_not_includes log.change_set.to_json, "password123"
  end

  test "NFR-17: ปิด/เปิดใช้งาน admin ลง log พร้อมเหตุผล" do
    post admin_admin_disablement_path(@other_admin), params: { disablement: { reason: "ลาออก" } }
    assert_equal [ "admin.deactivate", "ลาออก" ], [ AuditLog.last.action, AuditLog.last.reason ]
    delete admin_admin_disablement_path(@other_admin)
    assert_equal "admin.activate", AuditLog.last.action
  end

  test "NFR-17/18: รีเซ็ตรหัสผ่านลง log โดยไม่มีรหัสชั่วคราว" do
    post admin_user_password_reset_path(@user)
    temporary = css_select("code.ui-secret").text.strip
    assert temporary.present?
    log = AuditLog.last
    assert_equal "user.password_reset", log.action
    assert_equal @user, log.target
    assert_not_includes log.change_set.to_json, temporary
    assert_not_includes log.reason.to_s, temporary
  end

  test "NFR-17: การกระทำที่ไม่สำเร็จไม่ลง log" do
    assert_no_difference -> { AuditLog.count } do
      post admin_admin_disablement_path(@admin), params: { disablement: { reason: "ปิดตัวเอง" } }
      post admin_admins_path, params: { user: { username: "x", password: "1", password_confirmation: "1" } }
    end
  end

  # ---- หน้าดู (NFR-18)
  test "NFR-18: แสดงรายการล่าสุดก่อน พร้อมชื่อ action ภาษาไทยและเหตุผล" do
    AuditLog.record!(admin: @other_admin, action: "item.approve")
    travel 1.minute
    @user.suspend!(by: @admin, reason: "ฉ้อโกง")

    get admin_audit_logs_path
    assert_response :success
    rows = css_select("tbody tr")
    assert_match(/ระงับผู้ใช้/, rows.first.text)
    assert_match(/ฉ้อโกง/, rows.first.text)
    assert_match(/อนุมัติสินค้า/, rows.last.text)
  end

  test "NFR-18: กรองตาม admin / ประเภท / ช่วงเวลา / สิ่งที่ถูกกระทำ" do
    AuditLog.record!(admin: @other_admin, action: "item.approve")
    @user.suspend!(by: @admin, reason: "ทดสอบ")

    get admin_audit_logs_path, params: { admin_id: @other_admin.id }
    assert_select "tbody tr", 1
    assert_select "td", "อนุมัติสินค้า"

    get admin_audit_logs_path, params: { action_name: "user.suspend" }
    assert_select "tbody tr", 1
    assert_select "td", "ระงับผู้ใช้"

    get admin_audit_logs_path, params: { target_type: "User", target_id: @user.id }
    assert_select "tbody tr", 1

    get admin_audit_logs_path, params: { from: 1.day.from_now.to_date.iso8601 }
    assert_select ".ui-table__message", "ไม่พบรายการ"

    get admin_audit_logs_path, params: { from: "not-a-date" }
    assert_response :success
    assert_select "tbody tr", 2
  end

  test "NFR-18: ไม่มี route แก้หรือลบ audit log" do
    log = AuditLog.record!(admin: @admin, action: "item.approve")
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/admin/audit_logs/#{log.id}", method: :delete) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/admin/audit_logs/#{log.id}", method: :patch) }
  end

  test "AUTH-10: ผู้ประมูลดู audit log ไม่ได้" do
    delete logout_path
    sign_in(create_approved_bidder)
    get admin_audit_logs_path
    assert_response :forbidden
  end
end
