# ระเบียนที่มีประวัติลบจริงไม่ได้ ใช้ "เก็บถาวร" แทน (NFR-19, ITEM-12, ROOM-05)
# เก็บถาวรแล้วหายจากรายการปกติ (scope active) แต่ยัง find ด้วย id ได้ เพื่อให้ประวัติเก่าอ้างถึงได้
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current) unless archived?
  end
end
