# จัดรูปแบบเงินบาทและวันที่เวลา (NFR-01, NFR-02, NFR-09)
# เขตเวลาใช้ค่าของแอป (Asia/Bangkok, #69) จึงแปลงผ่าน in_time_zone ทุกครั้ง · ใช้ได้ทุก view โดยไม่ต้อง include
# ทุกตัวคืน "-" เมื่อค่าเป็น nil (ช่องที่ยังไม่มีข้อมูลจึงแสดงขีด ไม่ว่างเปล่า)
#
# ----- เงิน -----
#   baht(1800)                       # => "1,800 บาท"        รูปแบบมาตรฐานของระบบ (หน้า admin, ขั้นยืนยันก่อนยื่นราคา BID-20, การ์ดสินค้า)
#   baht(BigDecimal("1800.5"))       # => "1,800.50 บาท"     มีสตางค์เฉพาะเมื่อมีเศษ
#   baht_symbol(1800)                # => "฿1,800"           แบบสั้น สำหรับที่แคบ
#   plain_amount(BigDecimal("100"))  # => "100"              ค่าเงินในช่องกรอก (ไม่มี .0)
#   เงินรับเฉพาะ Integer / BigDecimal / Rational / String ตัวเลข ส่ง Float แล้ว raise ทันที (NFR-09)
#   จำนวนที่ใส่เข้ามา "หน่วยเป็นบาท" (ถ้าเก็บเป็นสตางค์ ให้หาร 100 เป็น BigDecimal ก่อนเรียก)
#
# ----- วันเวลา -----
#   display_time(t)                  # => "13/11/2026 20:00"            รูปแบบมาตรฐานของระบบ ปี ค.ศ. ตามที่ทีมใช้
#   display_time(t, precision: :millisecond) # => "13/11/2026 20:00:05.123"  หน้า admin ดูเวลาที่ยื่น (BID-13)
#   thai_datetime(t) / thai_date(t)  # => "13 พ.ย. 2569 20:00 น."        ปี พ.ศ. ทางเลือก ตอนนี้ไม่มีหน้าไหนใช้
#                                    #    (ถ้าทีมอยากเปลี่ยนทั้งระบบเป็น พ.ศ. ให้เปลี่ยน display_time แล้วลบสองตัวนี้)
module FormatHelper
  BUDDHIST_ERA_OFFSET = 543
  TIME_PRECISIONS = { minute: "%H:%M", second: "%H:%M:%S", millisecond: "%H:%M:%S.%L" }.freeze

  # 1,500,000.50 บาท (ไม่มีทศนิยมถ้าเป็นจำนวนเต็ม)
  def baht(amount)
    value = baht_value(amount)
    return "-" if value.nil?

    "#{number_to_currency(value, locale: :th, unit: '', format: '%n', negative_format: '-%n',
                                 precision: baht_precision(value))} บาท"
  end

  # ฿1,500,000.50
  def baht_symbol(amount)
    value = baht_value(amount)
    return "-" if value.nil?

    number_to_currency(value, locale: :th, precision: baht_precision(value))
  end

  # ค่าเงินในช่องกรอก: BigDecimal 100.0 → "100", 10.5 → "10.5" · ข้อความที่ผู้ใช้พิมพ์คงไว้ตามเดิม
  def plain_amount(value)
    return value unless value.is_a?(Numeric)

    value.to_d.to_s("F").delete_suffix(".0")
  end

  # วันเวลาแบบอ่านง่าย 11/11/2026 14:05 (ปี ค.ศ. ตามที่ทีมใช้อยู่)
  def display_time(time, precision: :minute)
    return "-" if time.nil?

    "#{time.in_time_zone.strftime('%d/%m/%Y')} #{time_of_day(time, precision)}"
  end

  # 13 พ.ย. 2569 (ปี พ.ศ.)
  def thai_date(value)
    return "-" if value.nil?

    day = value.respond_to?(:hour) ? value.in_time_zone : value # Date ไม่ผ่านการแปลงเขตเวลา
    "#{day.day} #{I18n.t('date.abbr_month_names', locale: :th)[day.month]} #{day.year + BUDDHIST_ERA_OFFSET}"
  end

  # 13 พ.ย. 2569 01:30 น. (ปี พ.ศ.)
  def thai_datetime(value, precision: :minute)
    return "-" if value.nil?

    "#{thai_date(value.in_time_zone)} #{time_of_day(value, precision)} น."
  end

  private

  def time_of_day(time, precision)
    format = TIME_PRECISIONS.fetch(precision) do
      raise ArgumentError, "precision ต้องเป็น #{TIME_PRECISIONS.keys.join(' / ')} (ได้ #{precision.inspect})"
    end
    time.in_time_zone.strftime(format)
  end

  def baht_value(amount)
    case amount
    when nil then nil
    when Float
      raise ArgumentError, "ห้ามใช้ Float กับเงิน (NFR-09) ใช้ Integer หรือ BigDecimal แทน (ได้ #{amount.inspect})"
    when BigDecimal then amount
    else BigDecimal(amount.to_s)
    end
  end

  def baht_precision(value)
    value.frac.zero? ? 0 : 2
  end
end
