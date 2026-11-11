require "test_helper"

# #30 AUTH-07 · #42 ADM-03/04/05/06/07/08
class AdminAdminsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @other = create_admin
    sign_in(@admin)
  end

  def create_admin_via_form(**overrides)
    post admin_admins_path, params: { user: { username: "newadmin", password: "password123", password_confirmation: "password123" }.merge(overrides) }
  end

  # ---- รายชื่อ (ADM-03)
  test "ADM-03: รายชื่อ admin แสดงสถานะ ใช้งาน/ปิดใช้งาน พร้อมเหตุผล" do
    @other.disable(by: @admin, reason: "ลาออกจากทีม")
    get admin_admins_path
    assert_response :success
    assert_select "td", /#{@admin.username}/
    assert_select ".ui-badge--success", "ใช้งาน"
    assert_select ".ui-badge--danger", "ปิดใช้งาน"
    assert_select "td", "ลาออกจากทีม"
  end

  test "ADM-07: ไม่มีปุ่มจัดการกับบัญชีของตัวเองในรายการ" do
    get admin_admins_path
    assert_select "tr", text: /#{@admin.username}/ do
      assert_select "form", count: 0
      assert_select "a[href*=disablement]", count: 0
    end
  end

  # ---- สร้าง admin (AUTH-07, ADM-04)
  test "AUTH-07: admin สร้างบัญชี admin ใหม่ได้ และ admin ใหม่ login ได้" do
    assert_difference -> { User.admin.count }, 1 do
      create_admin_via_form
    end
    assert_redirected_to admin_admins_path
    created = User.find_by!(username: "newadmin")
    assert created.admin?
    assert_nil created.email # ADM-04: มีเฉพาะ username/password
    assert_nil created.fullname

    delete logout_path
    sign_in(created)
    assert_redirected_to admin_root_path
  end

  test "ADM-04: ฟอร์มสร้าง admin มีเฉพาะ username/password/ยืนยัน" do
    get new_admin_admin_path
    assert_response :success
    assert_select "input[name=?]", "user[username]"
    assert_select "input[name=?]", "user[password]"
    assert_select "input[name=?]", "user[password_confirmation]"
    assert_select "input[name=?]", "user[email]", count: 0
    assert_select "input[name=?]", "user[fullname]", count: 0
  end

  test "AUTH-07: role มาจากระบบ ส่ง role=bidder มาไม่ได้เปลี่ยนผล และข้อมูลผิดถูกปฏิเสธ" do
    create_admin_via_form(role: "bidder")
    assert User.find_by!(username: "newadmin").admin?

    assert_no_difference -> { User.count } do
      create_admin_via_form(username: "ab", password: "short", password_confirmation: "nomatch")
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", minimum: 2
  end

  test "AUTH-04: username admin ซ้ำกับผู้ใช้ทั่วไป (ไม่สนตัวพิมพ์) ถูกปฏิเสธ" do
    bidder = create_bidder(username: "somchai")
    assert_no_difference -> { User.count } do
      create_admin_via_form(username: bidder.username.upcase)
    end
    assert_response :unprocessable_entity
  end

  # ---- ปิด/เปิดใช้งาน (ADM-05, 07, 08)
  test "ADM-05: ปิดใช้งานต้องมีเหตุผล" do
    post admin_admin_disablement_path(@other), params: { disablement: { reason: "  " } }
    assert_response :unprocessable_entity
    assert_select ".ui-alert--error", /เหตุผล/
    assert_not @other.reload.disabled?
  end

  test "ADM-05: ปิดใช้งานสำเร็จ บันทึกเหตุผลและผู้ปิด" do
    get new_admin_admin_disablement_path(@other)
    assert_response :success

    post admin_admin_disablement_path(@other), params: { disablement: { reason: "ลาออก" } }
    assert_redirected_to admin_admins_path
    @other.reload
    assert @other.disabled?
    assert_equal "ลาออก", @other.disabled_reason
    assert_equal @admin, @other.disabled_by
  end

  test "ADM-08: ปิดใช้งานแล้ว session ของบัญชีนั้นถูกลบทันที" do
    third = create_admin
    third.sessions.create!
    post admin_admin_disablement_path(third), params: { disablement: { reason: "ทดสอบ" } }
    assert_equal 0, third.sessions.count
  end

  test "ADM-05: เปิดใช้งานกลับได้ และ login ได้อีก" do
    @other.disable(by: @admin, reason: "ชั่วคราว")
    delete admin_admin_disablement_path(@other)
    assert_redirected_to admin_admins_path
    @other.reload
    assert_not @other.disabled?
    assert_nil @other.disabled_reason

    delete logout_path
    sign_in(@other)
    assert_redirected_to admin_root_path
  end

  test "ADM-07: ปิดใช้งานบัญชีตัวเองไม่ได้ (server ปฏิเสธแม้ยิงตรง)" do
    post admin_admin_disablement_path(@admin), params: { disablement: { reason: "x" } }
    assert_response :unprocessable_entity
    assert_select ".ui-alert--error", /ตัวเอง/
    assert_not @admin.reload.disabled?
  end

  test "ADM-07: ปิดใช้งานระดับโมเดล ต้องเหลือ admin ที่ใช้งานได้อย่างน้อย 1 คน" do
    # @admin และ @other คือ admin ที่ active ทั้งคู่ → ปิด @other โดย @admin ได้
    assert @other.disable(by: @admin, reason: "ok")
    # ตอนนี้ @admin คือ admin ที่ใช้งานได้คนสุดท้าย: ผู้กระทำคนอื่น (แม้ผิดปกติ เช่น race) ปิดไม่ได้
    ghost = create_admin
    ghost.update_columns(disabled_at: Time.current)
    assert_not @admin.disable(by: ghost, reason: "x")
    assert_includes @admin.errors.full_messages.to_sentence, "อย่างน้อย 1 คน"
    assert_not @admin.reload.disabled?
  end

  # ---- ห้ามลบ (ADM-06)
  test "ADM-06: ไม่มี route ลบ admin" do
    delete "/admin/admins/#{@other.id}"
    assert_response :not_found
    assert User.exists?(@other.id)
  end

  test "ADM-06: ลบ admin ผ่านโมเดลไม่ได้ (ใช้ปิดใช้งานแทน) และ session ไม่ถูกลบตามไปด้วย" do
    @other.sessions.create!
    assert_not @other.destroy
    assert User.exists?(@other.id)
    assert_equal 1, @other.sessions.count
    assert_includes @other.errors.full_messages.to_sentence, "ปิดใช้งาน"
  end

  test "ผู้ใช้ทั่วไปเปิด/ปิดใช้งานไม่ได้ (บัญชีผู้ประมูลไม่อยู่ใน route นี้)" do
    bidder = create_bidder
    get new_admin_admin_disablement_path(bidder.id)
    assert_response :not_found
    post admin_admin_disablement_path(bidder.id), params: { disablement: { reason: "x" } }
    assert_response :not_found
    assert_not bidder.reload.disabled?
  end
end
