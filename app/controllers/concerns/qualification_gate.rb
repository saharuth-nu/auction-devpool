# ผู้ประมูลที่ยังไม่ผ่านการตรวจคุณสมบัติ "ทำอะไรไม่ได้เลย" (QUAL-05, NFR-08) — task #35
#
# ปฏิเสธโดยค่าเริ่มต้นเหมือน Authentication: ทุก controller ที่ผู้ประมูลเข้าได้ จะส่งผู้ที่ยังไม่ผ่าน
# (รอกรอกทรัพย์สิน / รอ admin ตรวจ / ไม่ผ่าน) ไปหน้าสถานะ ยกเว้น controller ที่อยู่ใน allowlist ของ QUAL-05:
#   (1) หน้าสถานะ  (2) ส่ง/แก้ทรัพย์สิน  (3) logout  (4) บังคับเปลี่ยนรหัสผ่านหลังถูกรีเซ็ต (AUTH-13)
# ประกาศด้วย allow_unqualified_access เท่านั้น หน้าใหม่ของผู้ประมูลจึงปลอดภัยโดยอัตโนมัติ
# (โปรไฟล์และหน้าเปลี่ยนรหัสผ่านทั่วไปไม่อยู่ใน allowlist ตามเกณฑ์ตรวจรับของ QUAL-05)
module QualificationGate
  extend ActiveSupport::Concern

  included do
    before_action :require_qualification
  end

  class_methods do
    def allow_unqualified_access(**options)
      skip_before_action :require_qualification, **options
    end
  end

  private

  def require_qualification
    user = Current.user
    return unless user&.bidder?
    return if user.qualified?

    if request.get? || request.head?
      redirect_to qualification_path
    else
      redirect_to qualification_path, status: :see_other, alert: "ต้องผ่านการตรวจสอบคุณสมบัติก่อน"
    end
  end
end
