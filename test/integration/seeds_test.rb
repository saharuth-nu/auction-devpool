require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seed สร้างวิธี first_price 30 วินาที และรันซ้ำไม่สร้างซ้ำ (METH-04/07)" do
    # event/lot อ้างถึงวิธีประมูลด้วย FK แบบ restrict (NFR-19) จึงต้องล้างก่อน
    Lot.delete_all
    AuctionEvent.delete_all
    AuctionMethod.delete_all

    2.times { Rails.application.load_seed }

    method = AuctionMethod.sole
    assert_equal "first_price", method.code
    assert_equal 30, method.bidding_seconds
    assert method.enabled?
  end
end
