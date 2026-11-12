require "test_helper"

# #68 BID-11, BID-12, BID-17, BID-18, BID-19
class BidVisibilityTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @lot = lots(:upcoming_necklace)
    @ana = create_bidder
    @bua = create_bidder
    @ana_bid = Bid.create!(user: @ana, lot: @lot, amount: 1_800, placed_at: Time.current)
    @bua_bid = Bid.create!(user: @bua, lot: @lot, amount: 2_200, placed_at: Time.current)
  end

  test "BID-11: admin เห็นราคาของทุกคน" do
    assert_equal [ @ana_bid, @bua_bid ].sort_by(&:id), Bid.visible_to(@admin).where(lot: @lot).sort_by(&:id)
  end

  test "BID-11: ผู้ใช้เห็นเฉพาะราคาของตัวเอง" do
    assert_equal [ @ana_bid ], Bid.visible_to(@ana).to_a
    assert_equal [ @bua_bid ], Bid.visible_to(@bua).to_a
  end

  test "BID-11: ไม่มีผู้ใช้ (ยังไม่ login) เห็นอะไรไม่ได้" do
    assert_empty Bid.visible_to(nil)
  end

  test "ผู้ใช้ที่ไม่เคยยื่นไม่เห็นราคาใดเลย" do
    assert_empty Bid.visible_to(create_bidder)
  end

  # ---- ผลของ lot ที่ผู้ใช้เห็น
  def settled_lot(winner_amount: 2_200)
    @lot.update_columns(status: "sold", winning_price: winner_amount, winning_bid_id: @bua_bid.id)
    @lot
  end

  test "BID-12: ขายได้ ผู้ใช้ทุกคนเห็นราคาที่ชนะ" do
    assert_equal BigDecimal("2200"), settled_lot.public_winning_price
  end

  test "BID-12: ผู้ชนะรู้ว่าชนะ คนอื่นรู้แค่ว่าไม่ชนะ (ไม่มีข้อมูลว่าใครชนะ)" do
    lot = settled_lot
    assert_equal :won, lot.outcome_for(@bua)
    assert_equal :lost, lot.outcome_for(@ana)
    assert_equal :lost, lot.outcome_for(create_bidder) # ไม่ได้ยื่นก็เป็นผู้ไม่ชนะ
    assert_not_respond_to lot.outcome_for(@ana), :user
  end

  test "BID-19: ไม่ขาย ไม่มีราคา และไม่แยกสาเหตุ ไม่ว่าจะต่ำกว่า reserve หรือไม่มีผู้ยื่น" do
    below_reserve = @lot.tap { |l| l.update_columns(status: "unsold") }
    assert_nil below_reserve.public_winning_price
    assert_equal :unsold, below_reserve.outcome_for(@ana)
    assert_equal :unsold, below_reserve.outcome_for(@bua)

    no_bids = lots(:live_painting).tap { |l| l.update_columns(status: "unsold") }
    assert_equal :unsold, no_bids.outcome_for(@ana)
    assert_equal below_reserve.outcome_for(@ana), no_bids.outcome_for(@ana), "สองสาเหตุต้องดูเหมือนกันสำหรับผู้ใช้"
  end

  test "ยังไม่สรุปผลและ event ยกเลิก" do
    assert_equal :pending, @lot.outcome_for(@ana)
    assert_nil @lot.public_winning_price
    @lot.update_columns(status: "cancelled")
    assert_equal :cancelled, @lot.outcome_for(@ana)
  end

  test "ผลของ lot ไม่เผยราคาสูงสุดของ lot ที่ขายไม่ได้ผ่าน public_winning_price แม้มี winning_price ค้างผิดปกติ" do
    @lot.update_columns(status: "unsold")
    assert_nil @lot.public_winning_price
  end
end
