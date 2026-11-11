require "test_helper"

# requirements: QUAL-01..04, QUAL-07..09, QUAL-12..16 (requirements/01-accounts.md) · tasks #33 #34 #36 #37
class QualificationSubmissionTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @user = create_bidder
  end

  def rows(*pairs)
    pairs.map { |name, value| { name:, value: } }
  end

  # ---- สถานะเริ่มต้น / การส่ง
  test "QUAL-01: register แล้วสถานะเป็น รอกรอกทรัพย์สิน และ admin ไม่มีสถานะคุณสมบัติ" do
    assert @user.qualification_awaiting_assets?
    assert_equal "รอกรอกทรัพย์สิน", @user.qualification_status_label
    assert_nil @admin.qualification_status
  end

  test "QUAL-04: ส่งทรัพย์สินแล้วสถานะเป็น รอ admin ตรวจ และรอบเป็น pending" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "3000000" ], [ "รถ", "500000.50" ]))
    assert submission.persisted?, submission.errors.full_messages.inspect
    assert submission.pending?
    assert_not_nil submission.submitted_at
    assert @user.reload.qualification_awaiting_review?
    assert_equal [ "บ้าน", "รถ" ], submission.assets.map(&:name)
    assert_equal BigDecimal("3500000.50"), submission.total_value
  end

  test "QUAL-02: ต้องมีอย่างน้อย 1 รายการ และแถวว่างไม่นับ" do
    submission = QualificationSubmission.submit(@user, rows([ "", "" ], [ " ", nil ]))
    assert_not submission.persisted?
    assert submission.errors.include?(:assets)
    assert @user.reload.qualification_awaiting_assets?
  end

  test "QUAL-02: รับ params แบบ fields_for (hash ที่มี key เป็นลำดับ)" do
    params = { "0" => { "name" => "ที่ดิน", "value" => "1,200,000" }, "1" => { "name" => "", "value" => "" } }
    submission = QualificationSubmission.submit(@user, params)
    assert submission.persisted?, submission.errors.full_messages.inspect
    assert_equal BigDecimal("1200000"), submission.assets.first.value
  end

  test "QUAL-03a: ไม่เกิน 20 รายการต่อรอบ" do
    assert QualificationSubmission.submit(create_bidder, Array.new(20) { |i| { name: "รายการ #{i}", value: "1" } }).persisted?

    submission = QualificationSubmission.submit(@user, Array.new(21) { |i| { name: "รายการ #{i}", value: "1" } })
    assert_not submission.persisted?
    assert submission.errors.include?(:assets)
  end

  test "QUAL-03a: รายการที่ผิดกฎทำให้ทั้งรอบไม่ถูกบันทึก" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ], [ "รถ", "-5" ]))
    assert_not submission.persisted?
    assert_equal 0, QualificationSubmission.count
    assert @user.reload.qualification_awaiting_assets?
  end

  test "QUAL-12/QUAL-05: ส่งได้เฉพาะสถานะ รอกรอกทรัพย์สิน และ ไม่ผ่าน" do
    QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    second = QualificationSubmission.submit(@user.reload, rows([ "บ้าน", "999" ]))
    assert_not second.persisted?, "รอตรวจอยู่ต้องส่งซ้ำไม่ได้"

    approved = create_approved_bidder
    again = QualificationSubmission.submit(approved, rows([ "เพิ่มเพดาน", "99999999" ]))
    assert_not again.persisted?, "ผ่านแล้วต้องแก้ทรัพย์สินไม่ได้ (QUAL-12)"

    assert_not QualificationSubmission.submit(@admin, rows([ "x", "1" ])).persisted?, "admin ไม่มีขั้นส่งทรัพย์สิน"
  end

  test "QUAL-04: unique index กันมีรอบ pending ซ้อนกันแม้ข้าม validation" do
    QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    duplicate = @user.qualification_submissions.new(submitted_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  # ---- การตรวจของ admin (QUAL-07/08)
  test "QUAL-07: คิวตรวจมีเฉพาะรอบที่รอ เรียงตามเวลาส่ง และไม่มีผู้ใช้ที่ยังไม่กรอก" do
    first = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    travel 1.minute
    second = QualificationSubmission.submit(create_bidder, rows([ "รถ", "100" ]))
    create_bidder # รอกรอกทรัพย์สิน: ไม่อยู่ในคิว
    create_approved_bidder(admin: @admin)

    assert_equal [ first, second ], QualificationSubmission.review_queue.to_a
  end

  test "QUAL-07/QUAL-10: admin กดผ่าน → ผู้ใช้สถานะ ผ่าน และลง audit log" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    submission.approve!(@admin)

    assert submission.reload.approved?
    assert_equal @admin, submission.reviewed_by
    assert_not_nil submission.reviewed_at
    assert @user.reload.qualified?

    log = AuditLog.last
    assert_equal "qualification.approve", log.action
    assert_equal @admin, log.admin
    assert_equal @user, log.target
  end

  test "QUAL-08: ไม่ผ่านต้องมีเหตุผล และผู้ใช้เห็นเหตุผลนั้น" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    assert_raises(ActiveRecord::RecordInvalid) { submission.reject!(@admin, "  ") }
    assert submission.reload.pending?, "เหตุผลว่างต้องไม่เปลี่ยนสถานะ"
    assert @user.reload.qualification_awaiting_review?

    submission.reject!(@admin, "มูลค่าไม่สมเหตุสมผล")
    assert @user.reload.qualification_rejected?
    assert_equal "มูลค่าไม่สมเหตุสมผล", @user.latest_rejection_reason
    assert_equal "qualification.reject", AuditLog.last.action
    assert_equal "มูลค่าไม่สมเหตุสมผล", AuditLog.last.reason
  end

  test "QUAL-07: ตรวจซ้ำรอบเดิมไม่ได้ และผู้ตรวจต้องเป็น admin" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    assert_raises(ArgumentError) { submission.approve!(create_bidder) }
    submission.approve!(@admin)
    assert_raises(QualificationSubmission::NotReviewable) { submission.reject!(@admin, "เปลี่ยนใจ") }
    assert submission.reload.approved?
  end

  # ---- ส่งใหม่และประวัติ (QUAL-09/13/14/15)
  test "QUAL-09/QUAL-15: ไม่ผ่านแล้วส่งใหม่ได้ เป็นรอบใหม่ และฟอร์มเริ่มจากรายการรอบก่อน" do
    first = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ], [ "รถ", "50" ]))
    first.reject!(@admin, "ขาดรายละเอียด")

    assert_equal [ { name: "บ้าน", value: BigDecimal("100") }, { name: "รถ", value: BigDecimal("50") } ],
                 @user.reload.asset_rows_for_resubmission

    second = QualificationSubmission.submit(@user, rows([ "บ้านเดี่ยว", "120" ]))
    assert second.persisted?
    assert_not_equal first.id, second.id
    assert @user.reload.qualification_awaiting_review?
    assert_nil @user.latest_rejection_reason, "รอบล่าสุดยังไม่ได้ตรวจ"
  end

  test "QUAL-13: รอบที่ตรวจแล้วและทรัพย์สินแก้หรือลบไม่ได้" do
    submission = QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ]))
    submission.reject!(@admin, "ไม่ผ่าน")

    assert_raises(ActiveRecord::ReadOnlyRecord) { submission.reload.update!(rejection_reason: "แก้ย้อนหลัง") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { submission.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { submission.assets.first.update!(value: 999) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { submission.assets.first.destroy }
    assert QualificationSubmission.exists?(submission.id)
  end

  test "QUAL-14: เก็บทุกรอบ เรียงล่าสุดก่อน" do
    QualificationSubmission.submit(@user, rows([ "บ้าน", "100" ])).reject!(@admin, "รอบ 1")
    travel 1.minute
    QualificationSubmission.submit(@user.reload, rows([ "บ้าน", "200" ])).reject!(@admin, "รอบ 2")
    travel 1.minute
    QualificationSubmission.submit(@user.reload, rows([ "บ้าน", "300" ]))

    history = @user.qualification_submissions.newest_first.to_a
    assert_equal 3, history.size
    assert_equal %w[pending rejected rejected], history.map(&:status)
    assert_equal [ 300, 200, 100 ], history.map { |s| s.total_value.to_i }
  end

  # ---- เพดานราคา (QUAL-11/16)
  test "QUAL-11/QUAL-16: เพดาน = ผลรวมของรอบที่ผ่านเท่านั้น" do
    assert_equal 0, @user.bid_ceiling

    QualificationSubmission.submit(@user, rows([ "บ้าน", "9999999" ])).reject!(@admin, "สูงเกินจริง")
    assert_equal 0, @user.reload.bid_ceiling, "รอบที่ไม่ผ่านไม่นับ"

    second = QualificationSubmission.submit(@user, rows([ "บ้าน", "3000" ], [ "รถ", "2000.25" ]))
    assert_equal 0, @user.reload.bid_ceiling, "รอบที่รอตรวจไม่นับ"

    second.approve!(@admin)
    assert_equal BigDecimal("5000.25"), @user.reload.bid_ceiling
  end
end
