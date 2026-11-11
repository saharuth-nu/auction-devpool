# สถานะคุณสมบัติของผู้ประมูลและเพดานราคา
# tasks #35 #37 · QUAL-01, QUAL-04, QUAL-05, QUAL-10, QUAL-11, QUAL-12, QUAL-16
#
# สถานะ 4 ค่า (admin เป็น NULL):
#   awaiting_assets (รอกรอกทรัพย์สิน) → awaiting_review (รอ admin ตรวจ) → approved (ผ่าน) | rejected (ไม่ผ่าน)
#   rejected → ส่งใหม่ → awaiting_review
module User::Qualification
  extend ActiveSupport::Concern

  STATUS_LABELS = {
    "awaiting_assets" => "รอกรอกทรัพย์สิน",
    "awaiting_review" => "รอ admin ตรวจ",
    "approved" => "ผ่าน",
    "rejected" => "ไม่ผ่าน"
  }.freeze

  included do
    enum :qualification_status,
         { awaiting_assets: "awaiting_assets", awaiting_review: "awaiting_review",
           approved: "approved", rejected: "rejected" },
         prefix: :qualification, validate: { allow_nil: true }

    has_many :qualification_submissions, dependent: :restrict_with_exception
    has_many :reviewed_qualification_submissions, class_name: "QualificationSubmission",
                                                  foreign_key: :reviewed_by_id,
                                                  dependent: :restrict_with_exception

    before_validation :set_initial_qualification_status, on: :create
    validates :qualification_status, presence: true, if: :bidder?
    validates :qualification_status, absence: true, if: :admin?
  end

  def qualification_status_label
    STATUS_LABELS[qualification_status]
  end

  # QUAL-05 (2): ส่ง/แก้ทรัพย์สินได้เฉพาะ "รอกรอกทรัพย์สิน" และ "ไม่ผ่าน" (รอตรวจและผ่านแล้วล็อก QUAL-12)
  def can_submit_assets?
    bidder? && (qualification_awaiting_assets? || qualification_rejected?)
  end

  # QUAL-10: ผ่านแล้วใช้งานฝั่งผู้ใช้ได้เต็มรูปแบบ (การระงับตรวจแยกใน User::Suspension)
  def qualified?
    bidder? && qualification_approved?
  end

  def latest_qualification_submission
    qualification_submissions.newest_first.first
  end

  # QUAL-08: เหตุผลที่ไม่ผ่านของรอบล่าสุด (nil ถ้ารอบล่าสุดไม่ใช่ "ไม่ผ่าน")
  def latest_rejection_reason
    latest = latest_qualification_submission
    latest.rejection_reason if latest&.rejected?
  end

  # QUAL-15: แถวเริ่มต้นของฟอร์มส่งใหม่ = รายการของรอบก่อน
  def asset_rows_for_resubmission
    latest_qualification_submission&.asset_rows || []
  end

  # QUAL-11/16: เพดานราคาที่ยื่นได้ = ผลรวมทรัพย์สินของรอบล่าสุดที่ "ผ่าน" (ไม่นับรอบอื่น)
  # คืน 0 ถ้ายังไม่เคยผ่าน
  def bid_ceiling
    submission = qualification_submissions.approved.newest_first.first
    submission ? submission.assets.sum(:value) : BigDecimal("0")
  end

  private

  def set_initial_qualification_status
    self.qualification_status ||= "awaiting_assets" if bidder?
  end
end
