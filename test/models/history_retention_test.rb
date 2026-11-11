require "test_helper"

# requirements: NFR-19 (ห้ามลบข้อมูลประวัติ) สำหรับตารางของ tasks #33 #38 #71
# การลบบัญชีที่มีประวัติต้องถูกปฏิเสธ ทั้งผ่าน model และที่ระดับฐานข้อมูล (ไม่มี cascade)
class HistoryRetentionTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @user = create_bidder
    QualificationSubmission.submit(@user, [ { name: "บ้าน", value: "100" } ]).reject!(@admin, "ไม่ผ่าน")
    @user.reload.suspend!(by: @admin, reason: "ทดสอบ")
  end

  test "NFR-19: ลบผู้ใช้ที่มีรอบส่งตรวจ/ประวัติระงับผ่าน model ไม่ได้" do
    assert_raises(ActiveRecord::DeleteRestrictionError) { @user.destroy }
    assert User.exists?(@user.id)
  end

  test "NFR-19: ลบตรงที่ฐานข้อมูลก็ไม่ได้ (foreign key ไม่ cascade)" do
    assert_raises(ActiveRecord::InvalidForeignKey) { User.where(id: @user.id).delete_all }
    assert_raises(ActiveRecord::InvalidForeignKey) { User.where(id: @admin.id).delete_all }
    assert_equal 1, QualificationSubmission.where(user: @user).count
    assert_equal 1, SuspensionEvent.where(user: @user).count
    assert AuditLog.where(admin: @admin).exists?
  end
end
