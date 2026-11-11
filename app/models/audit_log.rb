# ประวัติการกระทำของ admin — เพิ่มได้อย่างเดียว (task #71 · NFR-17, NFR-18)
#
# ใช้ผ่าน AuditLog.record! เท่านั้น เช่น
#   AuditLog.record!(admin: current_admin, action: "item.approve", target: item,
#                    change_set: { status: [ "pending", "available" ] })
#
# action ต้องอยู่ใน ACTIONS (เพื่อให้หน้า admin กรองตามประเภทได้ครบ) งานใหม่ที่ต้องลง log ให้เพิ่มชื่อที่นี่
class AuditLog < ApplicationRecord
  ACTIONS = %w[
    item.create item.update item.destroy item.archive item.approve
    event.create event.update event.cancel
    auction_method.enable auction_method.disable
    qualification.approve qualification.reject
    user.suspend user.unsuspend user.password_reset
    admin.create admin.deactivate admin.activate
    bids.view
  ].freeze

  # NFR-18: ห้ามเก็บรหัสผ่านหรือรหัสชั่วคราวใน log แม้ส่งมาใน change_set
  # ตรงชื่อที่เก็บค่าลับจริง ไม่รวม flag อย่าง must_change_password
  SENSITIVE_KEY = /\A(password|password_confirmation|temporary_password|temp_password|\w*_digest|\w*token|\w*secret)\z/i
  REDACTED = "[ไม่บันทึก]".freeze

  belongs_to :admin, class_name: "User"
  belongs_to :target, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validate :admin_must_be_admin

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_id:) if admin_id.present? }
  scope :by_action, ->(action) { where(action:) if action.present? }
  scope :for_target, ->(type, id = nil) {
    next all if type.blank?
    id.present? ? where(target_type: type, target_id: id) : where(target_type: type)
  }
  scope :between, ->(from, to) {
    rel = all
    rel = rel.where(created_at: from..) if from.present?
    rel = rel.where(created_at: ..to) if to.present?
    rel
  }

  # ตัวกรองรวมของหน้า admin (NFR-18): admin_id, action, target_type, target_id, from, to
  def self.filter(params)
    params = params.to_h.symbolize_keys
    newest_first
      .by_admin(params[:admin_id])
      .by_action(params[:action])
      .for_target(params[:target_type], params[:target_id])
      .between(params[:from], params[:to])
  end

  def self.record!(admin:, action:, target: nil, change_set: {}, reason: nil)
    create!(admin:, action:, target:, change_set: redact(change_set), reason:)
  end

  def self.redact(hash)
    hash.to_h.each_with_object({}) do |(key, value), out|
      out[key.to_s] = if key.to_s.match?(SENSITIVE_KEY)
        REDACTED
      elsif value.is_a?(Hash)
        redact(value)
      else
        value
      end
    end
  end

  # append-only: บันทึกแล้วแก้หรือลบไม่ได้
  def readonly?
    persisted? || super
  end

  def destroy
    raise ActiveRecord::ReadOnlyRecord, "audit log ลบไม่ได้"
  end

  def delete
    destroy
  end

  private

  def admin_must_be_admin
    errors.add(:admin, "ต้องเป็นบัญชี admin") if admin && !admin.admin?
  end
end
