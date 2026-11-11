require "test_helper"

# #36 QUAL-07/08 คิวตรวจของ admin · NFR-13 ขั้นยืนยัน · NFR-17 audit log
class AdminQualificationSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @user = create_bidder(username: "somchai", fullname: "สมชาย ใจดี")
    @submission = QualificationSubmission.submit(@user, [ { name: "บ้าน", value: "3000000" }, { name: "รถ", value: "500000" } ])
    sign_in(@admin)
  end

  test "QUAL-07: คิวแสดงผู้ใช้ที่รอตรวจ ไม่แสดงผู้ที่ยังไม่กรอกหรือตรวจแล้ว" do
    create_bidder(username: "notyet")
    create_approved_bidder(username: "already", admin: @admin)
    get admin_qualification_submissions_path
    assert_response :success
    assert_select "td", "somchai"
    assert_select "td", { text: "notyet", count: 0 }
    assert_select "td", { text: "already", count: 0 }
    assert_select "td.num", "3,500,000 บาท"
  end

  test "QUAL-07: คิวว่างแสดงข้อความ" do
    @submission.approve!(@admin)
    get admin_qualification_submissions_path
    assert_select ".ui-table__message", "ไม่มีผู้ใช้ที่รอตรวจ"
  end

  test "QUAL-07: หน้าตรวจแสดงรายการทรัพย์สิน และปุ่มมีขั้นยืนยัน (NFR-13)" do
    get admin_qualification_submission_path(@submission)
    assert_response :success
    assert_select "td", "บ้าน"
    assert_select "td", "รถ"
    # ui_button_to ใส่ data-turbo-confirm ที่ปุ่ม (Turbo อ่านจาก submitter ได้)
    assert_select "form[action='#{approve_admin_qualification_submission_path(@submission)}'] button[data-turbo-confirm]"
    assert_select "form[action='#{reject_admin_qualification_submission_path(@submission)}'][data-turbo-confirm]"
  end

  test "QUAL-07: กดผ่าน → ผู้ใช้ผ่าน และลง audit log" do
    post approve_admin_qualification_submission_path(@submission)
    assert_redirected_to admin_qualification_submissions_path
    assert @user.reload.qualified?
    assert_equal BigDecimal("3500000"), @user.bid_ceiling
    assert_equal "qualification.approve", AuditLog.last.action
  end

  test "QUAL-08: ไม่ผ่านโดยไม่มีเหตุผลถูกปฏิเสธ แสดง error ใต้ช่อง และยังรอตรวจ" do
    post reject_admin_qualification_submission_path(@submission), params: { rejection: { reason: "  " } }
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /ต้องระบุเหตุผล/
    assert @submission.reload.pending?
    assert @user.reload.qualification_awaiting_review?
  end

  test "QUAL-08: ไม่ผ่านพร้อมเหตุผล → ผู้ใช้เห็นเหตุผลนั้น" do
    post reject_admin_qualification_submission_path(@submission), params: { rejection: { reason: "เอกสารไม่ชัด" } }
    assert_redirected_to admin_qualification_submissions_path
    assert @user.reload.qualification_rejected?
    assert_equal "เอกสารไม่ชัด", @user.latest_rejection_reason
    assert_equal "เอกสารไม่ชัด", AuditLog.last.reason
  end

  test "QUAL-07: ตรวจซ้ำรอบที่ตรวจแล้วไม่ได้" do
    post approve_admin_qualification_submission_path(@submission)
    post reject_admin_qualification_submission_path(@submission), params: { rejection: { reason: "เปลี่ยนใจ" } }
    assert_redirected_to admin_qualification_submission_path(@submission)
    assert_equal "รอบนี้ตรวจแล้ว", flash[:alert]
    assert @submission.reload.approved?
  end

  test "AUTH-10: ผู้ประมูลเข้าคิวตรวจหรือกดผ่านเองไม่ได้" do
    delete logout_path
    sign_in(create_approved_bidder)
    get admin_qualification_submissions_path
    assert_response :forbidden
    post approve_admin_qualification_submission_path(@submission)
    assert_response :forbidden
    assert @submission.reload.pending?
  end
end
