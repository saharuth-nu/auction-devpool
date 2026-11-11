require "test_helper"

# requirements: NFR-17, NFR-18 (requirements/05-non-functional.md) · task #71
class AuditLogTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @user = create_bidder
  end

  test "NFR-17: บันทึก admin เวลา การกระทำ เป้าหมาย ค่าก่อน/หลัง และเหตุผล" do
    log = AuditLog.record!(admin: @admin, action: "user.password_reset", target: @user,
                           change_set: { must_change_password: [ false, true ] }, reason: "ลืมรหัส")
    log.reload
    assert_equal @admin, log.admin
    assert_equal "user.password_reset", log.action
    assert_equal @user, log.target
    assert_equal({ "must_change_password" => [ false, true ] }, log.change_set)
    assert_equal "ลืมรหัส", log.reason
    assert_not_nil log.created_at
  end

  test "NFR-17: action ต้องอยู่ในรายการที่กำหนด และผู้ทำต้องเป็น admin" do
    assert_raises(ActiveRecord::RecordInvalid) { AuditLog.record!(admin: @admin, action: "item.teleport") }
    assert_raises(ActiveRecord::RecordInvalid) { AuditLog.record!(admin: @user, action: "item.create") }
  end

  test "NFR-18: ทุก action มีชื่อภาษาไทยสำหรับหน้าดู/ตัวกรอง" do
    assert_equal AuditLog::ACTIONS.sort, AuditLog::ACTION_LABELS.keys.sort
    assert_equal "ระงับผู้ใช้", AuditLog.new(action: "user.suspend").action_label
  end

  test "NFR-17: ไม่ต้องมีเป้าหมายก็บันทึกได้" do
    assert AuditLog.record!(admin: @admin, action: "admin.create").persisted?
  end

  test "NFR-18: แก้ไขหรือลบไม่ได้" do
    log = AuditLog.record!(admin: @admin, action: "item.approve")
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.update!(action: "item.create") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.delete }
    assert AuditLog.exists?(log.id)
  end

  test "NFR-18: ไม่เก็บรหัสผ่านหรือรหัสชั่วคราว แม้ส่งมาใน change_set (รวมที่ซ้อนอยู่)" do
    log = AuditLog.record!(admin: @admin, action: "user.password_reset", target: @user,
                           change_set: { password: "secret123", temporary_password: "Tmp-999",
                                         must_change_password: [ false, true ],
                                         nested: { password_digest: "x", note: "ok" }, username: "u1" })
    stored = log.reload.change_set.to_json
    assert_not_includes stored, "secret123"
    assert_not_includes stored, "Tmp-999"
    assert_equal AuditLog::REDACTED, log.change_set["password"]
    assert_equal AuditLog::REDACTED, log.change_set["nested"]["password_digest"]
    assert_equal "ok", log.change_set["nested"]["note"]
    assert_equal "u1", log.change_set["username"]
    assert_equal [ false, true ], log.change_set["must_change_password"], "flag ไม่ใช่ค่าลับ"
  end

  test "NFR-18: กรองตาม admin / ประเภท / ช่วงเวลา / สิ่งที่ถูกกระทำ เรียงล่าสุดก่อน" do
    other_admin = create_admin
    old = AuditLog.record!(admin: @admin, action: "item.approve")
    travel 2.days
    mine = AuditLog.record!(admin: @admin, action: "user.suspend", target: @user)
    theirs = AuditLog.record!(admin: other_admin, action: "user.suspend", target: create_bidder)

    assert_equal [ theirs, mine, old ], AuditLog.filter({}).to_a
    assert_equal [ mine, old ], AuditLog.filter(admin_id: @admin.id).to_a
    assert_equal [ theirs, mine ], AuditLog.filter(action: "user.suspend").to_a
    assert_equal [ mine ], AuditLog.filter(target_type: "User", target_id: @user.id).to_a
    assert_equal [ theirs, mine ], AuditLog.filter(from: 1.day.ago).to_a
    assert_equal [ old ], AuditLog.filter(to: 1.day.ago).to_a
  end
end
