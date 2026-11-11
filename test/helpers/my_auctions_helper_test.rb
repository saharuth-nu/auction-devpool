require "test_helper"

class MyAuctionsHelperTest < ActionView::TestCase
  include UiHelper

  test "countdown_text รูปแบบ HH:MM:SS และมีวันนำหน้าเมื่อเกิน 1 วัน" do
    assert_equal "00:00:00", countdown_text(0)
    assert_equal "00:00:01", countdown_text(0.2) # ปัดขึ้น ไม่แสดง 0 ก่อนถึงเวลาจริง
    assert_equal "00:04:15", countdown_text(255)
    assert_equal "01:00:00", countdown_text(3600)
    assert_equal "1 วัน 02:03:04", countdown_text(86_400 + 2 * 3600 + 3 * 60 + 4)
    assert_equal "00:00:00", countdown_text(-5)
  end

  test "countdown_to ส่งวินาทีที่เหลือให้ Stimulus และมีข้อความตั้งต้น (ใช้ได้แม้ปิด JS)" do
    travel_to Time.zone.local(2026, 11, 13, 10, 0, 0) do
      node = Nokogiri::HTML.fragment(countdown_to(Time.zone.local(2026, 11, 13, 12, 30, 15))).at_css("span.ui-countdown")
      assert_equal "countdown", node["data-controller"]
      assert_equal "9015.0", node["data-countdown-remaining-value"]
      assert_equal "02:30:15", node.text
    end
  end

  test "countdown_to เลยเวลาแล้วเหลือ 0 ไม่ติดลบ" do
    node = Nokogiri::HTML.fragment(countdown_to(1.hour.ago)).at_css("span.ui-countdown")
    assert_equal "0.0", node["data-countdown-remaining-value"]
    assert_equal "00:00:00", node.text
  end

  test "my_lot_badge ตามสถานะของ lot" do
    lot = Lot.new
    assert_match "ถูกยกเลิก", my_lot_badge(Lot.new(status: :cancelled), :upcoming)
    assert_match "ขายแล้ว", my_lot_badge(Lot.new(status: :sold), :finished)
    assert_match "ไม่ขาย", my_lot_badge(Lot.new(status: :unsold), :finished)
    assert_match "รอสรุปผล", my_lot_badge(lot, :finished)
    assert_nil my_lot_badge(lot, :upcoming)
    assert_nil my_lot_badge(lot, :live)
  end
end
