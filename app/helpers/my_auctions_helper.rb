# ตัวช่วยของหน้า "การประมูลของฉัน" (USR-16, USR-17)
module MyAuctionsHelper
  # เวลาที่เหลืออ่านง่าย "1 วัน 02:03:04" / "00:04:15" (เหมือนที่ countdown_controller.js นับต่อบนหน้าจอ)
  def countdown_text(seconds)
    total = [ seconds.ceil, 0 ].max
    days, rest = total.divmod(86_400)
    hours, rest = rest.divmod(3600)
    minutes, secs = rest.divmod(60)
    clock = format("%02d:%02d:%02d", hours, minutes, secs)
    days.positive? ? "#{days} วัน #{clock}" : clock
  end

  # ตัวนับถอยหลังถึงเวลาเริ่ม: เซิร์ฟเวอร์ส่งวินาทีที่เหลือ เบราว์เซอร์แค่นับลง (แสดงผลเท่านั้น NFR-03)
  def countdown_to(time)
    remaining = Clock.remaining(time)
    content_tag(:span, countdown_text(remaining), class: "ui-countdown",
                data: { controller: "countdown", countdown_remaining_value: remaining })
  end

  # สถานะของ lot ในประวัติการเข้าร่วม (ผลแพ้ชนะอยู่ที่หน้าผลการประมูล #61)
  def my_lot_badge(lot, phase)
    case lot.status
    when "cancelled" then ui_badge("ถูกยกเลิก", tone: :danger)
    when "sold" then ui_badge("ขายแล้ว", tone: :success)
    when "unsold" then ui_badge("ไม่ขาย", tone: :neutral)
    else ui_badge("รอสรุปผล", tone: :warning) if phase == :finished
    end
  end
end
