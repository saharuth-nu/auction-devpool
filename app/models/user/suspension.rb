# ระงับ / ยกเลิกระงับบัญชีผู้ประมูล (task #38 · SUSP-01, SUSP-07, SUSP-08, SUSP-09)
#
# การระงับแยกจากสถานะคุณสมบัติ: ระงับแล้ว qualification_status คงเดิม และยกเลิกแล้วกลับมาสถานะเดิม (SUSP-07)
# ผลต่อ login/session (#39) และต่อการประมูล (#40) อยู่ใน task ของคนอื่น ใช้ suspended? เป็นตัวตรวจ
module User::Suspension
  extend ActiveSupport::Concern

  class Error < StandardError; end

  included do
    has_many :suspension_events, dependent: :restrict_with_exception

    scope :suspended, -> { where.not(suspended_at: nil) }
    scope :not_suspended, -> { where(suspended_at: nil) }
  end

  # suspended? และการตัด session/ห้าม login (SUSP-02) อยู่ใน User และ Authentication (#39)

  # SUSP-01: ต้องมีเหตุผล · SUSP-09: ใช้กับ bidder เท่านั้น · SUSP-08 + NFR-17: บันทึกประวัติและ audit log
  def suspend!(by:, reason:)
    change_suspension!(by:, reason:, action: :suspend)
  end

  # SUSP-07: ยกเลิกระงับ ผู้ใช้กลับมาด้วยสถานะคุณสมบัติเดิม
  def unsuspend!(by:, reason:)
    change_suspension!(by:, reason:, action: :unsuspend)
  end

  private

  def change_suspension!(by:, reason:, action:)
    raise Error, "ผู้ทำต้องเป็น admin" unless by&.admin?
    raise Error, "ระงับได้เฉพาะบัญชีผู้ใช้ (bidder)" unless bidder?

    transaction do
      lock!
      if action == :suspend
        raise Error, "บัญชีนี้ถูกระงับอยู่แล้ว" if suspended?
      else
        raise Error, "บัญชีนี้ไม่ได้ถูกระงับ" unless suspended?
      end

      event = suspension_events.create!(admin: by, action:, reason: reason.to_s.strip)
      before = suspended_at
      update_columns(suspended_at: action == :suspend ? event.created_at : nil, updated_at: Time.current)
      AuditLog.record!(admin: by, action: "user.#{action}", target: self, reason: event.reason,
                       change_set: { suspended_at: [ before, suspended_at ] })
      event
    end
  end
end
