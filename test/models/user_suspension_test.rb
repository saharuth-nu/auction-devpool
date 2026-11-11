require "test_helper"

# requirements: SUSP-01, SUSP-07, SUSP-08, SUSP-09, NFR-17 (requirements/01-accounts.md) · task #38
class UserSuspensionTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @user = create_approved_bidder(admin: @admin)
  end

  test "SUSP-01: admin ระงับผู้ใช้ได้พร้อมเหตุผล" do
    @user.suspend!(by: @admin, reason: "พฤติกรรมไม่สุจริต")
    assert @user.reload.suspended?
    assert_includes User.suspended, @user
    assert_not_includes User.not_suspended, @user
  end

  test "SUSP-01: เหตุผลบังคับกรอก — ว่างแล้วไม่ระงับ" do
    assert_raises(ActiveRecord::RecordInvalid) { @user.suspend!(by: @admin, reason: "   ") }
    assert_not @user.reload.suspended?
    assert_equal 0, SuspensionEvent.count
  end

  test "SUSP-01: ผู้ทำต้องเป็น admin และระงับซ้ำไม่ได้" do
    assert_raises(User::Suspension::Error) { @user.suspend!(by: create_bidder, reason: "x") }
    @user.suspend!(by: @admin, reason: "ครั้งแรก")
    assert_raises(User::Suspension::Error) { @user.suspend!(by: @admin, reason: "ซ้ำ") }
  end

  test "SUSP-09: ระงับบัญชี admin ไม่ได้ (admin ใช้การปิดใช้งาน ADM-05)" do
    assert_raises(User::Suspension::Error) { create_admin.suspend!(by: @admin, reason: "x") }
  end

  test "SUSP-07: ยกเลิกระงับแล้วกลับมาด้วยสถานะคุณสมบัติเดิม" do
    @user.suspend!(by: @admin, reason: "ตรวจสอบ")
    assert @user.reload.qualification_approved?, "ระงับไม่เปลี่ยนสถานะคุณสมบัติ"

    @user.unsuspend!(by: @admin, reason: "ตรวจแล้วไม่พบปัญหา")
    assert_not @user.reload.suspended?
    assert @user.qualified?
    assert_raises(User::Suspension::Error) { @user.unsuspend!(by: @admin, reason: "ซ้ำ") }
  end

  test "SUSP-07: ผู้ใช้ที่ยังไม่ผ่านตรวจ ระงับแล้วยกเลิกก็กลับสถานะเดิม" do
    pending_user = create_bidder
    pending_user.suspend!(by: @admin, reason: "สแปม")
    pending_user.unsuspend!(by: @admin, reason: "ผิดคน")
    assert pending_user.reload.qualification_awaiting_assets?
  end

  test "SUSP-08: ทุกครั้งที่ระงับ/ยกเลิกบันทึกประวัติ admin เวลา เหตุผล และลบไม่ได้" do
    other_admin = create_admin
    @user.suspend!(by: @admin, reason: "เหตุผล 1")
    travel 1.hour
    @user.unsuspend!(by: other_admin, reason: "เหตุผล 2")

    events = @user.suspension_events.newest_first.to_a
    assert_equal %w[unsuspend suspend], events.map(&:action)
    assert_equal [ other_admin, @admin ], events.map(&:admin)
    assert_equal [ "เหตุผล 2", "เหตุผล 1" ], events.map(&:reason)
    assert events.all?(&:created_at)

    assert_raises(ActiveRecord::ReadOnlyRecord) { events.first.update!(reason: "แก้") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { events.first.destroy }
  end

  test "NFR-17: ระงับและยกเลิกระงับลง audit log พร้อมเหตุผล" do
    @user.suspend!(by: @admin, reason: "ฉ้อโกง")
    @user.unsuspend!(by: @admin, reason: "ยกเลิก")

    logs = AuditLog.where(target: @user).newest_first.to_a
    assert_equal %w[user.unsuspend user.suspend], logs.first(2).map(&:action)
    assert_equal "ฉ้อโกง", logs.second.reason
  end
end
