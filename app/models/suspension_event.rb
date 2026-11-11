# ประวัติการระงับ / ยกเลิกระงับบัญชีผู้ใช้หนึ่งครั้ง (task #38 · SUSP-08) — เพิ่มได้อย่างเดียว
class SuspensionEvent < ApplicationRecord
  REASON_MAX = 1000

  enum :action, { suspend: "suspend", unsuspend: "unsuspend" }

  belongs_to :user
  belongs_to :admin, class_name: "User"

  validates :reason, presence: { message: "ต้องระบุเหตุผล" },
                     length: { maximum: REASON_MAX, message: "ยาวไม่เกิน %{count} ตัวอักษร" }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def readonly?
    persisted? || super
  end

  def destroy
    raise ActiveRecord::ReadOnlyRecord, "ประวัติการระงับลบไม่ได้"
  end

  def delete
    destroy
  end
end
