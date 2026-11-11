require "test_helper"

class LotTest < ActiveSupport::TestCase
  test "lot ใหม่เริ่มที่ pending" do
    lot = Lot.create!(auction_event: auction_events(:upcoming), item: items(:car))
    assert lot.pending?
  end

  test "สินค้าเดียวกันใส่ event เดียวกันซ้ำไม่ได้" do
    lot = Lot.new(auction_event: auction_events(:upcoming), item: items(:necklace))
    assert_not lot.valid?
    assert lot.errors.of_kind?(:item_id, :taken)
  end

  test "สินค้าอยู่ได้ event เดียวในเวลาเดียว (ITEM-10)" do
    lot = Lot.new(auction_event: auction_events(:upcoming), item: items(:painting))
    assert_not lot.valid?
    assert lot.errors.of_kind?(:item, :in_other_event)
  end

  test "สินค้าที่ event เดิมถูกยกเลิกแล้ว ใส่ event ใหม่ได้ (ITEM-10)" do
    auction_events(:upcoming).cancel!
    other = AuctionEvent.create!(name: "รอบใหม่", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
      starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour)

    assert Lot.new(auction_event: other, item: items(:necklace)).valid?
  end

  test "สินค้าที่ขายได้แล้วต้องมีราคาผู้ชนะ" do
    lot = lots(:live_painting)
    lot.status = :sold
    assert_not lot.valid?
    assert lot.errors.of_kind?(:winning_price, :blank)
  end

  test "นำสินค้าออกจาก event ที่เริ่มแล้วไม่ได้ (EVT-08)" do
    assert_not lots(:live_painting).destroy
    assert Lot.exists?(lots(:live_painting).id)
  end

  test "นำสินค้าออกจาก event ที่ยังไม่เริ่มได้" do
    assert lots(:upcoming_necklace).destroy
  end
end
