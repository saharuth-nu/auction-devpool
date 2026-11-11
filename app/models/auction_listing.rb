# สินค้าที่แสดงในหน้าแรกของผู้ใช้ (USR-01..03, issue #57)
#
# USR-03: แสดงเฉพาะสินค้าที่อยู่ใน event ที่ "ยังไม่สรุปผล" (ยังไม่เริ่ม หรือกำลังประมูล)
# สินค้า "พร้อมขาย" ที่ยังไม่อยู่ใน event ไม่แสดง ดังนั้นต้องกรองจากสถานะของ event ไม่ใช่ของสินค้า
#
# รอ AuctionEvent และ Lot (issues #53, #54 ของสาย EVT) ตอนนี้จึงยังไม่มีสินค้าให้แสดง
# เมื่อโมเดลนั้นเข้ามา แก้ที่ `entries` เมธอดเดียว ให้คืน Entry เรียงตามเวลาเริ่มก่อน→หลัง เช่น
#
#   AuctionEvent.where(status: %w[scheduled open]).includes(lots: { item: { images_attachments: :blob } })
#               .flat_map { |event| event.lots.map { |lot| Entry.new(item: lot.item, starts_at: event.starts_at) } }
#               .sort_by(&:starts_at)
#
# หน้าและการ์ดสินค้าไม่ต้องแก้ (รับ Entry เหมือนเดิม)
class AuctionListing
  Entry = Data.define(:item, :starts_at)

  class << self
    def entries
      []
    end
  end
end
