# ราคาที่ผู้ใช้ยื่นต่อสินค้า (lot) หนึ่งชิ้น (BID-01, BID-13, NFR-05, NFR-19)
#
# - ยื่นได้ครั้งเดียวต่อ (user, lot): validation + unique index ที่ DB (การยิงซ้ำพร้อมกันสำเร็จได้ครั้งเดียว)
# - แก้ไขและลบไม่ได้ (BID-01, NFR-19): บันทึกแล้วเป็น readonly และ destroy/delete ถูกปฏิเสธ
# - placed_at ละเอียดระดับไมโครวินาที ใช้ตัดสินราคาเท่ากัน ผู้ยื่นก่อนชนะ (BID-07)
# - การตรวจสิทธิ์/เวลา/ช่วงราคาอยู่ที่ PlaceBid (#64) ที่นี่ตรวจเฉพาะความถูกต้องของข้อมูลเอง
#
# ราคาของผู้อื่นเป็นความลับ (BID-11, NFR-04): ห้ามส่ง Bid ของคนอื่นไปหน้าผู้ใช้ ดู Bid::Visibility
class Bid < ApplicationRecord
  belongs_to :user
  belongs_to :lot

  validates :amount, numericality: { greater_than: 0 }
  validates :placed_at, presence: true
  validates :user_id, uniqueness: { scope: :lot_id, message: "คุณยื่นราคาสินค้านี้แล้ว" }

  # คัดผู้ชนะ (BID-06, BID-07): ราคาสูงสุดก่อน เท่ากันให้ผู้ยื่นก่อน (placed_at น้อยกว่า) และ id เป็นตัวตัดสินสุดท้าย
  scope :for_settlement, -> { order(amount: :desc, placed_at: :asc, id: :asc) }

  # แก้ไขไม่ได้หลังบันทึก (BID-01) · update_columns/อัปเดตตรงด้วย SQL ยังทำได้ จึงมี check constraint และ test ครอบ
  def readonly?
    persisted? || super
  end

  # ไม่ลบประวัติราคาที่ยื่น (BID-13, NFR-19)
  def destroy
    raise ActiveRecord::ReadOnlyRecord, "ราคาที่ยื่นแล้วลบไม่ได้"
  end

  def delete
    destroy
  end
end
