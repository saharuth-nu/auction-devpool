# การส่งทรัพย์สินให้ admin ตรวจหนึ่งรอบ
# tasks #33 #34 #36 #37 · QUAL-02, QUAL-03a, QUAL-04, QUAL-07, QUAL-08, QUAL-09, QUAL-13, QUAL-15
#
# - สร้างผ่าน QualificationSubmission.submit(user, assets_attributes) เท่านั้น
# - ตรวจผ่าน approve!(admin) / reject!(admin, reason) ซึ่งเปลี่ยนสถานะผู้ใช้และลง audit log
# - รอบที่ตรวจแล้วแก้/ลบไม่ได้ รอบเก่าไม่ถูกแตะ (QUAL-13)
class QualificationSubmission < ApplicationRecord
  MAX_ASSETS = 20
  REJECTION_REASON_MAX = 1000

  # ผลตรวจ: pending = รอตรวจ, approved = ผ่าน, rejected = ไม่ผ่าน
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, default: :pending

  class NotReviewable < StandardError; end

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :assets, -> { order(:position, :id) }, inverse_of: :qualification_submission,
                                                  dependent: :restrict_with_exception
  accepts_nested_attributes_for :assets

  validates :submitted_at, presence: true
  validate :assets_count_within_limits, on: :create
  validate :user_can_submit, on: :create
  validates :rejection_reason, presence: { message: "ต้องระบุเหตุผล" },
                               length: { maximum: REJECTION_REASON_MAX, message: "ยาวไม่เกิน %{count} ตัวอักษร" },
                               if: :rejected?

  before_validation :set_submitted_at, on: :create
  before_validation :number_asset_positions, on: :create
  after_create :mark_user_awaiting_review
  before_update :forbid_changes_after_review

  scope :chronological, -> { order(:submitted_at, :id) }
  scope :newest_first, -> { order(submitted_at: :desc, id: :desc) }
  # คิวตรวจของ admin (QUAL-07): รอบที่ยังรอ เรียงจากส่งก่อน
  scope :review_queue, -> { pending.chronological.includes(:user, :assets) }

  # ผู้ใช้ส่งทรัพย์สินรอบใหม่ (QUAL-02/04/09) คืน submission ที่บันทึกแล้วหรือยังไม่บันทึก (มี errors)
  # assets_attributes: [{ name:, value: }, ...] หรือ hash แบบ fields_for ({ "0" => {...} })
  def self.submit(user, assets_attributes)
    submission = user.qualification_submissions.build(assets_attributes: compact_rows(assets_attributes))
    user.with_lock { submission.save }
    submission
  rescue ActiveRecord::RecordNotUnique
    submission.errors.add(:base, "มีรอบที่รอตรวจอยู่แล้ว")
    submission
  end

  # แถวที่ว่างทั้งชื่อและมูลค่าถือว่าผู้ใช้ไม่ได้กรอก (ฟอร์มหลายแถว) ไม่นับเป็นรายการ
  def self.compact_rows(rows)
    rows = rows.to_h.values if rows.respond_to?(:keys)
    Array(rows).map { |row| row.to_h.symbolize_keys.slice(:name, :value) }
               .reject { |row| row[:name].blank? && row[:value].blank? }
  end

  # รายการของรอบก่อนสำหรับเติมฟอร์มส่งใหม่ (QUAL-15)
  def asset_rows
    assets.map { |a| { name: a.name, value: a.value } }
  end

  def total_value
    assets.sum(&:value)
  end

  # ไม่ลบรอบใดเลย ทั้งที่รอและที่ตรวจแล้ว (QUAL-13, NFR-19)
  def destroy
    raise ActiveRecord::ReadOnlyRecord, "รอบส่งตรวจลบไม่ได้"
  end

  def delete
    destroy
  end

  def approve!(admin)
    review!(admin, :approved)
  end

  def reject!(admin, reason)
    review!(admin, :rejected, reason)
  end

  private

  def review!(admin, result, reason = nil)
    raise ArgumentError, "ผู้ตรวจต้องเป็น admin" unless admin&.admin?

    transaction do
      lock!
      raise NotReviewable, "รอบนี้ตรวจแล้ว" unless pending?

      update!(status: result, reviewed_by: admin, reviewed_at: Time.current, rejection_reason: reason.presence)
      user.update_columns(qualification_status: result.to_s, updated_at: Time.current)
      AuditLog.record!(admin:, action: "qualification.#{result == :approved ? 'approve' : 'reject'}",
                       target: user, reason: rejection_reason,
                       change_set: { submission_id: id, qualification_status: [ "awaiting_review", result.to_s ] })
    end
    self
  end

  def set_submitted_at
    self.submitted_at ||= Time.current
  end

  def number_asset_positions
    assets.each_with_index { |asset, i| asset.position = i }
  end

  def assets_count_within_limits
    count = assets.size
    errors.add(:assets, "ต้องมีอย่างน้อย 1 รายการ") if count.zero?
    errors.add(:assets, "ไม่เกิน #{MAX_ASSETS} รายการ") if count > MAX_ASSETS
  end

  # ส่งได้เฉพาะผู้ประมูลสถานะ "รอกรอกทรัพย์สิน" หรือ "ไม่ผ่าน" (QUAL-04, QUAL-05, QUAL-12)
  def user_can_submit
    return if user&.can_submit_assets?

    errors.add(:base, "ไม่สามารถส่งทรัพย์สินได้ในสถานะปัจจุบัน")
  end

  def mark_user_awaiting_review
    user.update_columns(qualification_status: "awaiting_review", updated_at: Time.current)
  end

  # หลังตรวจแล้วรอบนั้นคงที่ตลอดไป
  def forbid_changes_after_review
    return if status_in_database == "pending"

    raise ActiveRecord::ReadOnlyRecord, "รอบที่ตรวจแล้วแก้ไขไม่ได้"
  end
end
