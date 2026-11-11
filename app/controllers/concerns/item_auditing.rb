# ลง audit log ของสินค้า (NFR-17) ใช้ร่วมกันระหว่าง Admin::ItemsController กับ Admin::ItemImagesController
# เรียกภายใน transaction เดียวกับการเปลี่ยนแปลงเสมอ
module ItemAuditing
  extend ActiveSupport::Concern

  # ค่าที่เก็บใน log (ค่าเดิม→ใหม่) · ราคาอยู่ในนี้ตาม NFR-17
  AUDITED_ATTRIBUTES = %w[name description starting_price reserve_price].freeze

  private

  def audit_item!(action, change_set)
    AuditLog.record!(admin: current_user, action:, target: @item, change_set:)
  end
end
