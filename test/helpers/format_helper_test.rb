require "test_helper"

# NFR-01 (บาท), NFR-02 (เวลาไทย), NFR-09 (เงินห้ามเป็น float)
class FormatHelperTest < ActionView::TestCase
  test "NFR-01 baht แสดงบาทเต็มแบบคั่นหลักพันไม่มีสตางค์" do
    assert_equal "฿1,800", baht(1800)
    assert_equal "฿1,234,567", baht(1_234_567)
    assert_equal "฿0", baht(0)
    assert_equal "฿1,800", baht(BigDecimal("1800"))
    assert_equal "฿1,800", baht(BigDecimal("1800.00"))
  end

  test "NFR-01 baht แสดงสตางค์ 2 ตำแหน่งเมื่อมีเศษ" do
    assert_equal "฿1,800.50", baht(BigDecimal("1800.5"))
    assert_equal "฿0.25", baht(BigDecimal("0.25"))
  end

  test "NFR-01 baht ติดลบและรับสตริงตัวเลข" do
    assert_equal "-฿500", baht(-500)
    assert_equal "฿1,800", baht("1800")
  end

  test "NFR-01 baht เป็นบาทเสมอ แม้ locale ปัจจุบันเป็นอังกฤษ" do
    I18n.with_locale(:en) { assert_equal "฿1,800", baht(1800) }
  end

  test "BID-20 baht_text แสดงจำนวนเงินพร้อมหน่วย บาท" do
    assert_equal "1,800 บาท", baht_text(1800)
    assert_equal "1,000,000 บาท", baht_text(1_000_000)
    assert_equal "1,800.50 บาท", baht_text(BigDecimal("1800.5"))
    assert_equal "-500 บาท", baht_text(-500)
    I18n.with_locale(:en) { assert_equal "1,800 บาท", baht_text(1800) }
  end

  test "ค่า nil ได้ nil (ช่องที่ยังไม่มีข้อมูลว่างเฉยๆ)" do
    assert_nil baht(nil)
    assert_nil baht_text(nil)
    assert_nil thai_date(nil)
    assert_nil thai_datetime(nil)
  end

  test "NFR-09 เงินเป็น Float แล้ว raise" do
    error = assert_raises(ArgumentError) { baht(1800.0) }
    assert_match "Float", error.message
    assert_raises(ArgumentError) { baht_text(0.1 + 0.2) }
  end

  test "NFR-09 ตัวเลขที่อ่านไม่ได้ raise" do
    assert_raises(ArgumentError) { baht("ไม่ใช่ตัวเลข") }
  end

  test "NFR-02 thai_date เป็นเวลาไทยและปี พ.ศ." do
    assert_equal "13 พ.ย. 2569", thai_date(Time.zone.local(2026, 11, 13, 20, 0, 0))
    assert_equal "1 ม.ค. 2570", thai_date(Time.zone.local(2027, 1, 1))
  end

  test "NFR-02 เวลา UTC ที่ข้ามเที่ยงคืนไทยแสดงเป็นวันถัดไป" do
    # 12 พ.ย. 18:30 UTC = 13 พ.ย. 01:30 เวลาไทย
    utc = Time.utc(2026, 11, 12, 18, 30, 0)
    assert_equal "13 พ.ย. 2569", thai_date(utc)
    assert_equal "13 พ.ย. 2569 01:30 น.", thai_datetime(utc)
  end

  test "NFR-02 thai_date รับ Date ได้โดยไม่เลื่อนวัน" do
    assert_equal "31 ธ.ค. 2569", thai_date(Date.new(2026, 12, 31))
  end

  test "NFR-02 thai_datetime เลือกความละเอียดได้ (หน้า admin ดูเวลาที่ยื่นระดับมิลลิวินาที, BID-13)" do
    time = Time.zone.local(2026, 11, 13, 20, 0, 5, 123_456)
    assert_equal "13 พ.ย. 2569 20:00 น.", thai_datetime(time)
    assert_equal "13 พ.ย. 2569 20:00:05 น.", thai_datetime(time, precision: :second)
    assert_equal "13 พ.ย. 2569 20:00:05.123 น.", thai_datetime(time, precision: :millisecond)
  end

  test "thai_datetime ความละเอียดที่ไม่รู้จัก raise" do
    assert_raises(ArgumentError) { thai_datetime(Time.current, precision: :hour) }
  end

  test "NFR-01 ชื่อเดือนเป็นไทยเสมอ แม้ locale ปัจจุบันเป็นอังกฤษ" do
    I18n.with_locale(:en) { assert_equal "13 พ.ย. 2569", thai_date(Time.zone.local(2026, 11, 13)) }
  end
end
