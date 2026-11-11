require "test_helper"

# #29 AUTH-03, AUTH-03a, AUTH-17
class RegistrationsTest < ActionDispatch::IntegrationTest
  def register(**overrides)
    attrs = { fullname: "สมชาย ใจดี", username: "somchai", email: "somchai@example.com",
              password: "password123", password_confirmation: "password123", accept_terms: "1" }.merge(overrides)
    post registration_path, params: { user: attrs }
  end

  test "AUTH-03: มีหน้า register ครบ 5 ช่อง (รวมยืนยัน password)" do
    get new_registration_path
    assert_response :success
    %w[fullname username email password password_confirmation].each do |field|
      assert_select "input[name=?]", "user[#{field}]"
    end
    assert_select "a[href=?]", login_path
  end

  test "AUTH-03a: register สำเร็จ สร้างผู้ประมูลและ login ให้อัตโนมัติ" do
    assert_difference -> { User.bidder.count }, 1 do
      register
    end
    assert_redirected_to qualification_path # พาไปฟอร์มกรอกทรัพย์สินทันที (AUTH-03a, QUAL-02)

    user = User.find_by!(username: "somchai")
    assert user.bidder?
    assert_equal 1, user.sessions.count
    follow_redirect!
    assert_response :success # ไม่ต้องกลับไป login เอง
  end

  test "ความปลอดภัย: ส่ง role=admin มาไม่มีผล (ได้เป็น bidder เสมอ)" do
    post registration_path, params: { user: { fullname: "แฮกเกอร์", username: "hacker01", email: "h@example.com",
                                               password: "password123", password_confirmation: "password123", accept_terms: "1", role: "admin" } }
    assert User.find_by!(username: "hacker01").bidder?
    get admin_root_path
    assert_response :forbidden
  end

  test "ข้อมูลไม่ถูกต้อง: ไม่สร้างบัญชี ไม่ login และแสดง error ใต้ช่อง" do
    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      register(username: "ab", email: "not-an-email", password: "short", password_confirmation: "different")
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", minimum: 3
    assert_select "input[name=?].ui-input--invalid", "user[username]"
  end

  test "AUTH-04: username ซ้ำโดยต่างแค่ตัวพิมพ์ใหญ่เล็กถูกปฏิเสธ" do
    register
    delete logout_path
    assert_no_difference -> { User.count } do
      register(username: "SomChai", email: "other@example.com")
    end
    assert_response :unprocessable_entity
  end

  test "AUTH-05: email ซ้ำถูกปฏิเสธ" do
    register
    delete logout_path
    assert_no_difference -> { User.count } do
      register(username: "another01", email: "SOMCHAI@example.com")
    end
    assert_response :unprocessable_entity
  end

  test "ช่องยืนยัน password ไม่ตรงหรือว่างถูกปฏิเสธ" do
    assert_no_difference -> { User.count } do
      register(password_confirmation: "different123")
      register(password_confirmation: "")
    end
  end

  test "AUTH-19: ต้องติ๊กยอมรับเงื่อนไขและนโยบายก่อนสมัคร ไม่ติ๊กหรือไม่ส่งมาถูกปฏิเสธ" do
    assert_no_difference -> { User.count } do
      register(accept_terms: "0")
      assert_response :unprocessable_entity
      assert_select ".ui-field__error", /ต้องยอมรับเงื่อนไข/
      register(accept_terms: nil)
      assert_response :unprocessable_entity
    end
  end

  test "AUTH-19: หน้า register มีช่องติ๊กยอมรับ และลิงก์ไปหน้าเงื่อนไข" do
    get new_registration_path
    assert_select "input[type=checkbox][name=?]", "user[accept_terms]"
    assert_select "a[href=?]", terms_path
  end

  test "AUTH-19: สมัครสำเร็จบันทึกเวลาและเวอร์ชันที่ยินยอม" do
    travel_to Time.zone.parse("2026-11-12 09:30:00") do
      register
    end
    user = User.find_by!(username: "somchai")
    assert_equal Time.zone.parse("2026-11-12 09:30:00"), user.consented_at
    assert_equal Terms::VERSION, user.terms_version
  end

  test "AUTH-19: หน้าเงื่อนไขเปิดได้โดยไม่ต้อง login และมีส่วนนโยบายความเป็นส่วนตัว" do
    get terms_path
    assert_response :success
    assert_select "#privacy"
  end

  test "AUTH-19: admin เห็นเวลาที่ผู้ใช้ยินยอมในหน้ารายละเอียดผู้ใช้" do
    register
    user = User.find_by!(username: "somchai")
    delete logout_path
    sign_in(create_admin)
    get admin_user_path(user)
    assert_response :success
    assert_select "dt", "ยินยอมเงื่อนไข (PDPA)"
    assert_includes response.body, Terms::VERSION
  end

  test "ผู้ที่ login อยู่แล้วเปิดหน้า register ถูกส่งไปหน้าแรก" do
    register
    get new_registration_path
    assert_redirected_to root_path
  end

  test "ไม่เก็บรหัสผ่านเป็น plain text" do
    register
    assert_not_equal "password123", User.find_by!(username: "somchai").password_digest
  end
end
