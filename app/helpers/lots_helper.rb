# ช่วงเวลาของการประมูลสำหรับหน้ารายละเอียดสินค้า (USR-05) ตัดสินจากเวลาของเซิร์ฟเวอร์เสมอ (NFR-03)
#   :upcoming = ยังไม่ถึงเวลาเริ่ม (เข้าร่วมประมูลได้)
#   :open     = เริ่มแล้ว กำลังรับราคา
#   :closed   = เลยเวลารับราคาแล้ว (รอสรุปผล)
module LotsHelper
  def lot_phase(event)
    return :upcoming unless Clock.reached?(event.starts_at)

    Clock.passed?(event.bidding_ends_at) ? :closed : :open
  end

  # ป้ายสถานะตามช่วงเวลา: รอเริ่ม / กำลังประมูล / ปิดประมูล
  def lot_phase_badge(event)
    status_badge(:auction, { upcoming: :scheduled, open: :active, closed: :closed }.fetch(lot_phase(event)))
  end

  # ระยะเวลายื่นราคาที่อ่านง่าย มาจากวิธีประมูลของ event ไม่ฝังตัวเลข (METH-07)
  def bidding_window_text(auction_method)
    "#{auction_method.bidding_seconds} วินาทีหลังเริ่มประมูล"
  end
end
