require "test_helper"

# #43 METH-04/07: seed วิธีประมูล first_price (db/seeds/02_auction_methods.rb)
class AuctionMethodSeedsTest < ActiveSupport::TestCase
  test "seed สร้างวิธี first_price 30 วินาที และรันซ้ำไม่สร้างซ้ำ (METH-04/07)" do
    # event/lot อ้างถึงวิธีประมูลด้วย FK แบบ restrict (NFR-19) จึงต้องล้างก่อน
    Lot.delete_all
    AuctionEvent.delete_all
    AuctionMethod.delete_all

    2.times { load Rails.root.join("db/seeds/02_auction_methods.rb") }

    method = AuctionMethod.sole
    assert_equal "first_price", method.code
    assert_equal 30, method.bidding_seconds
    assert method.enabled?
  end

  test "db/seeds.rb โหลดไฟล์ seed วิธีประมูลด้วย" do
    Lot.delete_all
    AuctionEvent.delete_all
    AuctionMethod.delete_all

    load Rails.root.join("db/seeds.rb")

    assert AuctionMethod.exists?(code: "first_price")
  end
end
