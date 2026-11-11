# สินค้าที่ผู้ใช้เห็นได้ในหน้าแรกและหน้ารายละเอียด (USR-01..04, issues #57, #58)
#
# USR-03: แสดงเฉพาะสินค้าที่อยู่ใน event ที่ "ยังไม่สรุปผล" (ยังไม่เริ่ม หรือกำลังรับราคา)
# สินค้า "พร้อมขาย" ที่ยังไม่อยู่ใน event ไม่แสดง จึงกรองจากสถานะของ event และ lot ไม่ใช่ของสินค้า
#
# กติกา (lots):
#   - event ต้องยัง scheduled หรือ bidding (AuctionEvent.unfinished) · settled / cancelled ไม่แสดง
#   - lot ต้องยัง pending (sold / unsold / cancelled ไม่แสดง)
#   - สินค้าที่เก็บถาวรแล้วไม่แสดง (Item.active)
# หน้ารายละเอียดใช้ชุดเดียวกัน (lots.find) จึงเปิดดูได้เฉพาะ lot ที่หน้าแรกแสดง ที่เหลือเป็น 404
# entries เรียงตามเวลาเริ่มของ event ก่อน→หลัง และดึงรูปมาพร้อมกัน (preload) กันการ์ดแต่ละใบยิง query เพิ่ม
class AuctionListing
  # lot = ใช้ทำลิงก์ไปหน้ารายละเอียด (ไม่ใส่ก็ได้ การ์ดจะไม่เป็นลิงก์)
  Entry = Data.define(:item, :starts_at, :lot) do
    def initialize(item:, starts_at:, lot: nil) = super
  end

  class << self
    def lots
      Lot.pending
         .joins(:auction_event).merge(AuctionEvent.unfinished)
         .joins(:item).merge(Item.active)
    end

    def entries
      lots.includes(:auction_event, item: { images_attachments: :blob })
          .order(AuctionEvent.arel_table[:starts_at], Lot.arel_table[:id])
          .map { |lot| Entry.new(item: lot.item, starts_at: lot.auction_event.starts_at, lot:) }
    end
  end
end
