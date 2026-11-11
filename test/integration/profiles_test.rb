require "test_helper"

# #32 AUTH-18
class ProfilesTest < ActionDispatch::IntegrationTest
  setup do
    # ผ่านการตรวจคุณสมบัติแล้ว: ผู้ที่ยังไม่ผ่านเข้าได้เฉพาะหน้าสถานะ (QUAL-05) ดู qualification_gate_test.rb
    @bidder = create_approved_bidder(fullname: "สมหญิง รักเรียน")
    @admin = create_admin
  end

  test "AUTH-18: ผู้ใช้เห็น fullname, username, email และแก้ username ไม่ได้" do
    sign_in(@bidder)
    get profile_path
    assert_response :success
    assert_select "dd", /#{@bidder.username}/
    assert_select "dd", "สมหญิง รักเรียน"
    assert_select "dd", @bidder.email
    assert_select "main input", count: 0 # ไม่มีช่องแก้ข้อมูลในหน้าโปรไฟล์ (input ซ่อนของปุ่ม logout อยู่นอก main)
  end

  test "AUTH-18: admin เห็นเฉพาะ username (ไม่มี email/fullname)" do
    sign_in(@admin)
    get profile_path
    assert_response :success
    assert_select "dd", /#{@admin.username}/
    assert_select "dt", text: "อีเมล", count: 0
  end

  test "AUTH-18: ไม่มี route แก้โปรไฟล์ (username แก้ไม่ได้)" do
    sign_in(@bidder)
    patch "/profile", params: { user: { username: "hacked" } }
    assert_response :not_found
    assert_not_equal "hacked", @bidder.reload.username
  end

  test "AUTH-18: เปลี่ยนรหัสผ่านสำเร็จ ใช้รหัสใหม่ login ได้ รหัสเก่าใช้ไม่ได้" do
    sign_in(@bidder)
    get edit_password_path
    assert_response :success

    patch password_path, params: { user: { current_password: DEFAULT_PASSWORD, password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_redirected_to profile_path

    delete logout_path
    post login_path, params: { login: { username: @bidder.username, password: DEFAULT_PASSWORD } }
    assert_response :unprocessable_entity
    post login_path, params: { login: { username: @bidder.username, password: "brandnew123" } }
    assert_redirected_to root_path
  end

  test "AUTH-18: เปลี่ยนสำเร็จแล้ว session อื่นของบัญชีนั้นหมดผล แต่ session ปัจจุบันยังอยู่" do
    other_session = @bidder.sessions.create!
    sign_in(@bidder)
    current = @bidder.sessions.where.not(id: other_session.id).first

    patch password_path, params: { user: { current_password: DEFAULT_PASSWORD, password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_equal [ current.id ], @bidder.sessions.reload.pluck(:id)
    get profile_path
    assert_response :success
  end

  test "AUTH-18: ต้องกรอกรหัสเดิมให้ถูก" do
    sign_in(@bidder)
    patch password_path, params: { user: { current_password: "wrong-password", password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /ไม่ถูกต้อง/
    assert @bidder.reload.authenticate(DEFAULT_PASSWORD)
  end

  test "AUTH-18: รหัสใหม่ต้องผ่านกฎ AUTH-06 ไม่ซ้ำรหัสเดิม และยืนยันตรงกัน" do
    sign_in(@bidder)
    {
      "short" => [ "short", "short" ],
      "ยืนยันไม่ตรง" => [ "brandnew123", "other123456" ],
      "ซ้ำรหัสเดิม" => [ DEFAULT_PASSWORD, DEFAULT_PASSWORD ],
      "เกิน 72 ไบต์" => [ "a" * 73, "a" * 73 ]
    }.each do |name, (password, confirmation)|
      patch password_path, params: { user: { current_password: DEFAULT_PASSWORD, password: password, password_confirmation: confirmation } }
      assert_response :unprocessable_entity, name
    end
    assert @bidder.reload.authenticate(DEFAULT_PASSWORD)
  end

  test "AUTH-18: admin เปลี่ยนรหัสผ่านตัวเองได้" do
    sign_in(@admin)
    patch password_path, params: { user: { current_password: DEFAULT_PASSWORD, password: "brandnew123", password_confirmation: "brandnew123" } }
    assert_redirected_to profile_path
    assert @admin.reload.authenticate("brandnew123")
  end
end
