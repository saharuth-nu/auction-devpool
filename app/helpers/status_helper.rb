# แมปสถานะของโดเมน → ข้อความ + tone ของ Badge ที่เดียว (ดู DESIGN.md "สถานะของโดเมน")
# ห้ามกำหนดสีสถานะในแต่ละหน้า: เพิ่มสถานะใหม่ที่ STATUSES แล้วทุกหน้าได้สีเหมือนกัน
#
# ค่าตั้งต้นด้านล่างเป็นข้อเสนอเริ่มต้น ปรับให้ตรงกับ enum จริงของ model เมื่อสร้างแล้ว
module StatusHelper
  STATUSES = {
    auction: {
      "scheduled" => { label: "รอเริ่ม", tone: :warning },
      "active" => { label: "กำลังประมูล", tone: :success },
      "closed" => { label: "ปิดประมูล", tone: :neutral },
      "cancelled" => { label: "ยกเลิก", tone: :danger }
    },
    # สถานะคุณสมบัติของผู้ประมูล (QUAL, User::Qualification)
    qualification: {
      "awaiting_assets" => { label: "รอกรอกทรัพย์สิน", tone: :neutral },
      "awaiting_review" => { label: "รอ admin ตรวจ", tone: :warning },
      "approved" => { label: "ผ่าน", tone: :success },
      "rejected" => { label: "ไม่ผ่าน", tone: :danger }
    },
    # ผลตรวจของรอบส่งทรัพย์สิน (QualificationSubmission#status)
    submission: {
      "pending" => { label: "รอตรวจ", tone: :warning },
      "approved" => { label: "ผ่าน", tone: :success },
      "rejected" => { label: "ไม่ผ่าน", tone: :danger }
    },
    # การระงับบัญชีผู้ใช้ (SUSP): ส่ง user.suspended? ? "suspended" : "active"
    suspension: {
      "active" => { label: "ใช้งานได้", tone: :success },
      "suspended" => { label: "ถูกระงับ", tone: :danger }
    },
    # ประเภทเหตุการณ์ในประวัติการระงับ (SuspensionEvent#action)
    suspension_event: {
      "suspend" => { label: "ระงับ", tone: :danger },
      "unsuspend" => { label: "ยกเลิกระงับ", tone: :success }
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
