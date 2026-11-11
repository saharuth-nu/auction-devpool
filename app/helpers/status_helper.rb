# แมปสถานะของโดเมน → ข้อความ + tone ของ Badge ที่เดียว (ดู DESIGN.md "สถานะของโดเมน")
# ห้ามกำหนดสีสถานะในแต่ละหน้า: เพิ่มสถานะใหม่ที่ STATUSES แล้วทุกหน้าได้สีเหมือนกัน
#
# ค่าตั้งต้นด้านล่างเป็นข้อเสนอเริ่มต้น ปรับให้ตรงกับ enum จริงของ model เมื่อสร้างแล้ว
module StatusHelper
  STATUSES = {
    # ตรงกับ AuctionEvent.statuses (EVT-10)
    auction: {
      "scheduled" => { label: "ยังไม่เริ่ม", tone: :warning },
      "bidding" => { label: "เปิดรับราคา", tone: :success },
      "settled" => { label: "สรุปผลแล้ว", tone: :neutral },
      "cancelled" => { label: "ยกเลิก", tone: :danger }
    },
    # ตรงกับ Item.statuses (ITEM-02)
    item: {
      "awaiting_approval" => { label: "รออนุมัติ", tone: :warning },
      "available" => { label: "พร้อมขาย", tone: :success },
      "in_auction" => { label: "อยู่ระหว่างการประมูล", tone: :info },
      "sold" => { label: "ขายได้แล้ว", tone: :neutral }
    }
  }.freeze

  UNKNOWN_STATUS = { label: "ไม่ทราบ", tone: :muted }.freeze

  # { label:, tone: } ของสถานะ (ไม่รู้จัก → "ไม่ทราบ" ขอบประ)
  def status_style(domain, value)
    STATUSES.fetch(domain).fetch(value.to_s, UNKNOWN_STATUS)
  end

  # <%= status_badge(:auction, auction.status) %>
  def status_badge(domain, value)
    style = status_style(domain, value)
    ui_badge(style[:label], tone: style[:tone])
  end
end
