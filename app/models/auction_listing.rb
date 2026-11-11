# สินค้าที่แสดงในหน้าแรกของผู้ใช้ (USR-01..03, issue #57)
#
# USR-03: แสดงเฉพาะสินค้าที่อยู่ใน event ที่ "ยังไม่สรุปผล" (ยังไม่เริ่ม หรือกำลังรับราคา)
# สินค้า "พร้อมขาย" ที่ยังไม่อยู่ใน event ไม่แสดง จึงกรองจากสถานะของ event และ lot ไม่ใช่ของสินค้า
#
# กติกา:
#   - event ต้องยัง scheduled หรือ bidding (AuctionEvent.unfinished) · settled / cancelled ไม่แสดง
#   - lot ต้องยัง pending (sold / unsold / cancelled ไม่แสดง)
#   - สินค้าที่เก็บถาวรแล้วไม่แสดง (Item.active)
#   - เรียงตามเวลาเริ่มของ event ก่อน→หลัง (ใกล้ถึง/กำลังประมูลอยู่ก่อน)
# ดึงรูปมาพร้อมกัน (preload) กันการ์ดแต่ละใบยิง query เพิ่ม
class AuctionListing
  Entry = Data.define(:item, :starts_at)

  class << self
    def entries
      Lot.pending
         .joins(:auction_event).merge(AuctionEvent.unfinished)
         .joins(:item).merge(Item.active)
         .includes(:auction_event, item: { images_attachments: :blob })
         .order(AuctionEvent.arel_table[:starts_at], Lot.arel_table[:id])
         .map { |lot| Entry.new(item: lot.item, starts_at: lot.auction_event.starts_at) }
    end
  end
end
