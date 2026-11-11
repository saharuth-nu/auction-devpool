require "test_helper"

# #35 QUAL-05 / NFR-08: ผู้ประมูลที่ยังไม่ผ่านการตรวจทำได้เฉพาะ 4 อย่าง นอกนั้นถูกส่งไปหน้าสถานะ
class QualificationGateTest < ActionDispatch::IntegrationTest
  BLOCKED_GET_PATHS = %i[root_path profile_path edit_password_path].freeze

  def assert_sent_to_status_page
    assert_redirected_to qualification_path
  end

  def each_unqualified_bidder
    admin = create_admin
    awaiting_assets = create_bidder
    awaiting_review = create_bidder.tap { |u| QualificationSubmission.submit(u, [ { name: "บ้าน", value: "1" } ]) }
    rejected = create_bidder.tap do |u|
      QualificationSubmission.submit(u, [ { name: "บ้าน", value: "1" } ]).reject!(admin, "ไม่ผ่าน")
    end
    { awaiting_assets:, awaiting_review:, rejected: }.each do |status, user|
      assert_equal status.to_s, user.reload.qualification_status
      yield user, status
    end
  end

  test "QUAL-05: ผู้ที่ยังไม่ผ่านทุกสถานะเปิดหน้าอื่น (หน้าแรก โปรไฟล์ เปลี่ยนรหัสทั่วไป) ถูกส่งไปหน้าสถานะ" do
    each_unqualified_bidder do |user, status|
      sign_in(user)
      BLOCKED_GET_PATHS.each do |path|
        get public_send(path)
        assert_redirected_to qualification_path, "#{status}: #{path} ต้องถูกส่งไปหน้าสถานะ"
      end
      delete logout_path
    end
  end

  test "QUAL-05: request เปลี่ยนข้อมูลของหน้าอื่นก็ถูกปฏิเสธ (ไม่ใช่แค่ GET)" do
    user = create_bidder
    sign_in(user)
    patch password_path, params: { user: { current_password: DEFAULT_PASSWORD, password: "newpass999",
                                            password_confirmation: "newpass999" } }
    assert_response :see_other
    assert_redirected_to qualification_path
    assert user.reload.authenticate(DEFAULT_PASSWORD), "รหัสผ่านต้องไม่ถูกเปลี่ยน"
  end

  test "QUAL-05 (1)(3): หน้าสถานะและ logout ใช้ได้" do
    each_unqualified_bidder do |user, _status|
      sign_in(user)
      get qualification_path
      assert_response :success
      delete logout_path
      assert_redirected_to login_path
    end
  end

  test "QUAL-05 (4): บังคับเปลี่ยนรหัสผ่านหลังถูกรีเซ็ตใช้ได้ แล้วกลับไปหน้าสถานะ" do
    user = create_bidder
    temporary = user.reset_password(by: create_admin)
    sign_in(user, password: temporary)
    assert_redirected_to forced_password_path
    get forced_password_path
    assert_response :success

    patch forced_password_path, params: { user: { password: "brandnew123", password_confirmation: "brandnew123" } }
    follow_redirect!
    assert_redirected_to qualification_path
  end

  test "QUAL-10: ผู้ที่ผ่านแล้วเข้าหน้าแรกและโปรไฟล์ได้ และหน้าสถานะพากลับหน้าแรก" do
    sign_in(create_approved_bidder)
    get root_path
    assert_response :success
    get profile_path
    assert_response :success
    get qualification_path
    assert_redirected_to root_path
  end

  test "admin ไม่ถูกกระทบ และเปิดหน้าสถานะของผู้ใช้ไม่ได้" do
    sign_in(create_admin)
    get admin_root_path
    assert_response :success
    get qualification_path
    assert_response :forbidden
  end
end
