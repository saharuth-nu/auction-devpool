require "test_helper"

# #63 BID-01, BID-13, NFR-05, NFR-19
class BidTest < ActiveSupport::TestCase
  setup do
    @user = create_bidder
    @other = create_bidder
    @lot = lots(:upcoming_necklace)
  end

  def build_bid(**attrs)
    Bid.new({ user: @user, lot: @lot, amount: 1_800, placed_at: Time.current }.merge(attrs))
  end

  test "บันทึกราคาที่ยื่นได้" do
    bid = build_bid
    assert bid.save
    assert_equal BigDecimal("1800"), bid.reload.amount
  end

  test "BID-05: ราคาต้องมากกว่า 0 (ทั้ง validation และ check constraint ที่ DB)" do
    assert_not build_bid(amount: 0).valid?
    assert_not build_bid(amount: -5).valid?
    assert_not build_bid(amount: nil).valid?

    assert_raises(ActiveRecord::StatementInvalid) { build_bid(amount: 0).save(validate: false) }
  end

  test "ต้องมีเวลาที่ยื่น" do
    assert_not build_bid(placed_at: nil).valid?
  end

  test "BID-01/NFR-05: ยื่นได้ครั้งเดียวต่อ (ผู้ใช้, สินค้า) ที่ model" do
    assert build_bid.save
    dup = build_bid(amount: 2_500)
    assert_not dup.valid?
    assert_includes dup.errors[:user_id], "คุณยื่นราคาสินค้านี้แล้ว"
  end

  test "NFR-05: unique index ที่ DB กันยื่นซ้ำแม้ข้าม validation" do
    assert build_bid.save
    assert_raises(ActiveRecord::RecordNotUnique) { build_bid(amount: 2_500).save(validate: false) }
    assert_equal 1, Bid.where(user: @user, lot: @lot).count
  end

  test "คนละผู้ใช้หรือคนละสินค้ายื่นได้" do
    assert build_bid.save
    assert build_bid(user: @other).save
    assert build_bid(lot: lots(:live_painting)).save
  end

  test "BID-01: แก้ไขราคาที่ยื่นแล้วไม่ได้" do
    bid = build_bid.tap(&:save!)
    assert_raises(ActiveRecord::ReadOnlyRecord) { bid.update!(amount: 9_999) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { Bid.find(bid.id).update(amount: 9_999) }
    assert_equal BigDecimal("1800"), bid.reload.amount
  end

  test "BID-13/NFR-19: ลบราคาที่ยื่นไม่ได้" do
    bid = build_bid.tap(&:save!)
    assert_raises(ActiveRecord::ReadOnlyRecord) { bid.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { bid.delete }
    assert_equal 1, Bid.count
  end

  test "BID-13: เก็บเวลาที่ยื่นละเอียดระดับไมโครวินาที" do
    placed = Time.zone.parse("2026-11-13 10:00:05.200123")
    bid = build_bid(placed_at: placed).tap(&:save!)
    assert_equal 200_123, bid.reload.placed_at.usec
  end

  test "BID-07: for_settlement เรียงราคาสูงสุดก่อน ราคาเท่ากันให้ผู้ยื่นก่อนมาก่อน" do
    third = create_bidder
    late = build_bid(user: @user, amount: 1_800, placed_at: Time.zone.parse("2026-11-13 10:00:09.700")).tap(&:save!)
    early = build_bid(user: @other, amount: 1_800, placed_at: Time.zone.parse("2026-11-13 10:00:05.200")).tap(&:save!)
    top = build_bid(user: third, amount: 2_000, placed_at: Time.zone.parse("2026-11-13 10:00:20")).tap(&:save!)

    assert_equal [ top, early, late ], @lot.bids.for_settlement.to_a
  end

  test "ลบผู้ใช้หรือ lot ที่มีราคาที่ยื่นไว้ไม่ได้ (NFR-19)" do
    build_bid.save!
    assert_raises(ActiveRecord::DeleteRestrictionError) { @user.destroy }
    assert_not @lot.destroy
    assert_includes @lot.errors.full_messages.to_sentence, "ราคาที่ยื่นไว้แล้ว"
  end

  test "ผู้ชนะของ lot ชี้ไปที่ bid ได้ และลบ bid ที่เป็นผู้ชนะไม่ได้ที่ระดับ DB" do
    bid = build_bid.tap(&:save!)
    @lot.update_columns(winning_bid_id: bid.id)
    assert_equal bid, @lot.reload.winning_bid
    assert_raises(ActiveRecord::InvalidForeignKey) { Bid.connection.execute("DELETE FROM bids WHERE id = #{bid.id}") }
  end
end
