require "test_helper"

# NFR-01 (บาท), NFR-02 (เวลาไทย), NFR-09 (เงินห้ามเป็น float)
# รูปแบบมาตรฐานของระบบ: baht = "1,800 บาท", display_time = "13/11/2026 20:00" (ปี ค.ศ. ตามที่ทีมใช้)
# ส่วน baht พื้นฐานและ plain_amount ดู format_and_pagination_helper_test.rb
class FormatHelperTest < ActionView::TestCase
  test "NFR-01 baht คั่นหลักพัน ไม่มีสตางค์ถ้าเป็นบาทเต็ม" do
    assert_equal "1,800 บาท", baht(1800)
    assert_equal "1,234,567 บาท", baht(1_234_567)
    assert_equal "1,800 บาท", baht(BigDecimal("1800.00"))
    assert_equal "1,800.50 บาท", baht(BigDecimal("1800.5"))
    assert_equal "0.25 บาท", baht(BigDecimal("0.25"))
  end

  test "NFR-01 baht ติดลบ รับสตริงตัวเลข และเป็นบาทเสมอแม้ locale เป็นอังกฤษ" do
    assert_equal "-500 บาท", baht(-500)
    assert_equal "1,800 บาท", baht("1800")
    I18n.with_locale(:en) { assert_equal "1,800 บาท", baht(1800) }
  end

  test "NFR-01 baht_symbol แบบสั้นสำหรับที่แคบ" do
    assert_equal "฿1,800", baht_symbol(1800)
    assert_equal "฿1,800.50", baht_symbol(BigDecimal("1800.5"))
    assert_equal "-฿500", baht_symbol(-500)
    assert_equal "-", baht_symbol(nil)
    I18n.with_locale(:en) { assert_equal "฿1,800", baht_symbol(1800) }
  end

  test "NFR-09 เงินเป็น Float แล้ว raise" do
    error = assert_raises(ArgumentError) { baht(1800.0) }
    assert_match "Float", error.message
    assert_raises(ArgumentError) { baht_symbol(0.1 + 0.2) }
  end

  test "NFR-09 ตัวเลขที่อ่านไม่ได้ raise" do
    assert_raises(ArgumentError) { baht("ไม่ใช่ตัวเลข") }
  end

  test "ค่า nil ได้ขีด (ช่องที่ยังไม่มีข้อมูล)" do
    assert_equal "-", baht(nil)
    assert_equal "-", baht_symbol(nil)
    assert_equal "-", display_time(nil)
    assert_equal "-", thai_date(nil)
    assert_equal "-", thai_datetime(nil)
  end

  test "NFR-02 display_time เป็นเวลาไทย ปี ค.ศ." do
    assert_equal "13/11/2026 20:00", display_time(Time.zone.local(2026, 11, 13, 20, 0, 0))
  end

  test "NFR-02 เวลา UTC ที่ข้ามเที่ยงคืนไทยแสดงเป็นวันถัดไป" do
    # 12 พ.ย. 18:30 UTC = 13 พ.ย. 01:30 เวลาไทย
    utc = Time.utc(2026, 11, 12, 18, 30, 0)
    assert_equal "13/11/2026 01:30", display_time(utc)
    assert_equal "13 พ.ย. 2569 01:30 น.", thai_datetime(utc)
  end

  test "NFR-02 display_time เลือกความละเอียดได้ (หน้า admin ดูเวลาที่ยื่นระดับมิลลิวินาที BID-13)" do
    time = Time.zone.local(2026, 11, 13, 20, 0, 5, 123_456)
    assert_equal "13/11/2026 20:00", display_time(time)
    assert_equal "13/11/2026 20:00:05", display_time(time, precision: :second)
    assert_equal "13/11/2026 20:00:05.123", display_time(time, precision: :millisecond)
    assert_equal "13 พ.ย. 2569 20:00:05.123 น.", thai_datetime(time, precision: :millisecond)
  end

  test "ความละเอียดที่ไม่รู้จัก raise" do
    assert_raises(ArgumentError) { display_time(Time.current, precision: :hour) }
    assert_raises(ArgumentError) { thai_datetime(Time.current, precision: :hour) }
  end

  test "thai_date (ปี พ.ศ. ทางเลือก) รับ Date โดยไม่เลื่อนวัน และชื่อเดือนเป็นไทยเสมอ" do
    assert_equal "31 ธ.ค. 2569", thai_date(Date.new(2026, 12, 31))
    assert_equal "1 ม.ค. 2570", thai_date(Time.zone.local(2027, 1, 1))
    I18n.with_locale(:en) { assert_equal "13 พ.ย. 2569", thai_date(Time.zone.local(2026, 11, 13)) }
  end
end
