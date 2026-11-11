# รูปแบบตัวเลขเงินและเวลาที่ใช้ร่วมกันหลายหน้า (NFR-01, NFR-02)
# เขตเวลาใช้ค่าของแอป (#69 ตั้งเป็น Asia/Bangkok) จึงแปลงผ่าน in_time_zone ทุกครั้ง
module FormatHelper
  # 1500000.5 → "1,500,000.50 บาท" (ไม่มีทศนิยมถ้าเป็นจำนวนเต็ม: "1,500,000 บาท")
  def baht(amount)
    return "-" if amount.nil?

    precision = amount.to_d.frac.zero? ? 0 : 2
    "#{number_with_delimiter(number_with_precision(amount, precision:))} บาท"
  end

  # ค่าเงินในช่องกรอก: BigDecimal 100.0 → "100", 10.5 → "10.5" · ข้อความที่ผู้ใช้พิมพ์คงไว้ตามเดิม
  def plain_amount(value)
    return value unless value.is_a?(Numeric)

    value.to_d.to_s("F").delete_suffix(".0")
  end

  # วันเวลาแบบอ่านง่าย 11/11/2026 14:05 (ปี ค.ศ. ตามที่ทีมใช้อยู่)
  def display_time(time)
    return "-" if time.nil?

    time.in_time_zone.strftime("%d/%m/%Y %H:%M")
  end
end
