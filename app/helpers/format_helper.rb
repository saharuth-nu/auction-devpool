# จัดรูปแบบเงินบาทและวันที่เวลาแบบไทย (NFR-01, NFR-02, NFR-09)
#
# ใช้ได้ทุก view โดยไม่ต้อง include · ทุกตัวคืน nil เมื่อค่าเป็น nil (ช่องที่ยังไม่มีข้อมูลจึงว่างเฉยๆ)
#
#   baht(1800)                      # => "฿1,800"        ใช้ในรายการ/การ์ด
#   baht(BigDecimal("1800.5"))      # => "฿1,800.50"
#   baht_text(1800)                 # => "1,800 บาท"     ใช้ในขั้นยืนยันก่อนยื่นราคา (BID-20)
#   thai_date(time)                 # => "13 พ.ย. 2569"  ปี พ.ศ. เขตเวลา Asia/Bangkok
#   thai_datetime(time)             # => "13 พ.ย. 2569 01:30 น."
#   thai_datetime(time, precision: :millisecond) # => "13 พ.ย. 2569 01:30:05.123 น." (หน้า admin ดูราคาที่ยื่น)
#
# เงินรับเฉพาะ Integer / BigDecimal / Rational / String ตัวเลข ส่ง Float แล้ว raise ทันที (NFR-09)
# จำนวนที่ใส่เข้ามา "หน่วยเป็นบาท" (ถ้าเก็บเป็นสตางค์ ให้หาร 100 เป็น BigDecimal ก่อนเรียก)
module FormatHelper
  BUDDHIST_ERA_OFFSET = 543
  TIME_PRECISIONS = { minute: "%H:%M", second: "%H:%M:%S", millisecond: "%H:%M:%S.%L" }.freeze

  # ฿1,800 — ไม่แสดงสตางค์ถ้าเป็นบาทเต็ม แสดง 2 ตำแหน่งถ้ามีเศษ
  def baht(amount)
    value = baht_value(amount)
    return if value.nil?

    number_to_currency(value, locale: :th, precision: baht_precision(value))
  end

  # 1,800 บาท
  def baht_text(amount)
    value = baht_value(amount)
    return if value.nil?

    "#{number_to_currency(value, locale: :th, unit: '', format: '%n', negative_format: '-%n',
                                precision: baht_precision(value))} บาท"
  end

  # 13 พ.ย. 2569
  def thai_date(value)
    return if value.nil?

    day = value.respond_to?(:hour) ? value.in_time_zone : value # Date ไม่ผ่านการแปลงเขตเวลา
    "#{day.day} #{I18n.t('date.abbr_month_names', locale: :th)[day.month]} #{day.year + BUDDHIST_ERA_OFFSET}"
  end

  # 13 พ.ย. 2569 01:30 น.
  def thai_datetime(value, precision: :minute)
    return if value.nil?

    format = TIME_PRECISIONS.fetch(precision) do
      raise ArgumentError, "precision ต้องเป็น #{TIME_PRECISIONS.keys.join(' / ')} (ได้ #{precision.inspect})"
    end
    time = value.in_time_zone
    "#{thai_date(time)} #{time.strftime(format)} น."
  end

  private

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
