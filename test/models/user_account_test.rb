require "test_helper"

# พฤติกรรมบัญชีของ User: ปิดใช้งาน, รีเซ็ต/เปลี่ยนรหัสผ่าน, ลบ (AUTH-12/13/14/18, ADM-05/06/07)
class UserAccountTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @other = create_admin
    @bidder = create_bidder
  end

  test "generate_temporary_password: 12 ตัวอักษร a-z A-Z 0-9 และไม่ซ้ำกัน" do
    passwords = Array.new(20) { User.generate_temporary_password }
    assert(passwords.all? { |p| p.match?(/\A[A-Za-z0-9]{12}\z/) })
    assert_equal 20, passwords.uniq.size
  end

  test "active_for_login? ตามสถานะระงับ/ปิดใช้งาน" do
    assert @bidder.active_for_login?
    @bidder.update!(suspended_at: Time.current)
    assert_not @bidder.active_for_login?
    @bidder.update!(suspended_at: nil)
    @other.update!(disabled_at: Time.current)
    assert_not @other.active_for_login?
    assert_equal [ @admin.id, @bidder.id ].sort, User.active.pluck(:id).sort
  end

  test "disable: ต้องมีเหตุผล ห้ามปิดตัวเอง" do
    assert_not @other.disable(by: @admin, reason: nil)
    assert_not @other.disable(by: @admin, reason: " ")
    assert_not @admin.disable(by: @admin, reason: "x")
    assert_not @other.reload.disabled?
  end

  test "enable ล้างเหตุผลและผู้ปิด" do
    @other.disable(by: @admin, reason: "ชั่วคราว")
    @other.enable
    assert_nil @other.reload.disabled_at
    assert_nil @other.disabled_reason
    assert_nil @other.disabled_by
  end

  test "reset_password: ตั้ง must_change_password ลบ session และตัวเองรีเซ็ตไม่ได้" do
    @bidder.sessions.create!
    temporary = @bidder.reset_password(by: @admin)
    assert temporary
    assert @bidder.reload.must_change_password?
    assert @bidder.authenticate(temporary)
    assert_equal 0, @bidder.sessions.count

    assert_equal false, @admin.reset_password(by: @admin)
    assert_includes @admin.errors.full_messages.to_sentence, "ตัวเอง"
  end

  test "change_password: ต้องตรวจรหัสเดิมเมื่อส่งมา และไม่ตรวจเมื่อไม่ส่ง (บังคับเปลี่ยน)" do
    assert_not @bidder.change_password(current: "wrong", new_password: "brandnew123", confirmation: "brandnew123")
    assert_includes @bidder.errors[:current_password], "ไม่ถูกต้อง"
    assert @bidder.change_password(new_password: "brandnew123", confirmation: "brandnew123")
    assert @bidder.authenticate("brandnew123")
  end

  test "change_password: ล้าง must_change_password และลบ session อื่น คง session ที่ระบุไว้" do
    keep = @bidder.sessions.create!
    @bidder.sessions.create!
    @bidder.update!(must_change_password: true)
    assert @bidder.change_password(new_password: "brandnew123", confirmation: "brandnew123", keep_session: keep)
    assert_not @bidder.reload.must_change_password?
    assert_equal [ keep.id ], @bidder.sessions.pluck(:id)
  end

  test "change_password: ถ้าบันทึกไม่ผ่าน ไม่ล้างสถานะบังคับและไม่ลบ session" do
    @bidder.update!(must_change_password: true)
    session = @bidder.sessions.create!
    assert_not @bidder.change_password(new_password: "short", confirmation: "short")
    assert @bidder.reload.must_change_password?
    assert_includes @bidder.sessions.pluck(:id), session.id
  end

  test "ลบ admin ไม่ได้ แต่ผู้ประมูลที่ไม่มีประวัติลบได้ (กติกา NFR-19 ของผู้ประมูลเป็นงานสาย C)" do
    assert_not @admin.destroy
    assert User.exists?(@admin.id)
    assert @bidder.destroy
  end
end
