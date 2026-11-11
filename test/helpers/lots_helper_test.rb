require "test_helper"

# USR-05, NFR-03: ช่วงเวลาของการประมูลตัดสินจากเวลาของเซิร์ฟเวอร์ ที่ขอบเวลาแต่ละจุด
class LotsHelperTest < ActionView::TestCase
  include StatusHelper
  include UiHelper

  setup { @event = auction_events(:upcoming) } # วิธีประมูล first_price = 30 วินาที

  test "lot_phase ก่อนเริ่ม = upcoming ถึงเวลาเริ่มพอดี = open" do
    travel_to(@event.starts_at - 0.001.seconds, with_usec: true) { assert_equal :upcoming, lot_phase(@event) }
    travel_to(@event.starts_at) { assert_equal :open, lot_phase(@event) }
  end

  test "lot_phase ครบเวลารับราคาพอดียัง open เกินไปแม้ 1 มิลลิวินาทีเป็น closed" do
    travel_to(@event.bidding_ends_at) { assert_equal :open, lot_phase(@event) }
    travel_to(@event.bidding_ends_at + 0.001.seconds, with_usec: true) { assert_equal :closed, lot_phase(@event) }
  end

  test "lot_phase_badge ตามช่วงเวลา" do
    travel_to(@event.starts_at - 1.second) { assert_match "รอเริ่ม", lot_phase_badge(@event) }
    travel_to(@event.starts_at) { assert_match "กำลังประมูล", lot_phase_badge(@event) }
    travel_to(@event.bidding_ends_at + 1.second) { assert_match "ปิดประมูล", lot_phase_badge(@event) }
  end

  test "bidding_window_text อ่านจากวิธีประมูล" do
    assert_equal "30 วินาทีหลังเริ่มประมูล", bidding_window_text(auction_methods(:first_price))
    assert_equal "60 วินาทีหลังเริ่มประมูล", bidding_window_text(auction_methods(:english))
  end
end
