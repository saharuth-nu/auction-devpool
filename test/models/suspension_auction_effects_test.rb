require "test_helper"

# #40 SUSP-03, SUSP-04, SUSP-05, SUSP-06, SUSP-07
class SuspensionAuctionEffectsTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @method = auction_methods(:first_price)
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @items = %w[ก ข].map do |name|
      Item.create!(name: name, description: "x", starting_price: 1_000, reserve_price: 1_500).tap { |i| i.approve!(by: @admin) }
    end
    @event = AuctionEvent.create!(name: "รอบระงับ", room: rooms(:main_hall), auction_method: @method, starts_at: @starts_at,
                                  ends_at: @starts_at + 2.hours, selected_item_ids: @items.map(&:id))
    @lot_a, @lot_b = @event.lots.order(:id).to_a
    @user = create_approved_bidder(admin: @admin)
    @other = create_approved_bidder(admin: @admin)
    [ @lot_a, @lot_b ].each { |lot| [ @user, @other ].each { |u| Participation.create!(user: u, lot: lot) } }
  end

  test "SUSP-06: ระงับแล้วการเข้าร่วมใน event ที่ยังไม่เริ่มถูกยกเลิก (ทุก lot) และคืนที่นั่ง" do
    assert_equal 2, Participation.participants_count(@event)

    @user.suspend!(by: @admin, reason: "ทดสอบ")

    assert_equal 0, Participation.active.where(user: @user).count
    assert_equal 2, Participation.cancelled.where(user: @user).count
    assert_equal 1, Participation.participants_count(@event), "ที่นั่งของผู้ถูกระงับต้องถูกคืน"
  end

  test "SUSP-06: ไม่แตะการเข้าร่วมของผู้ใช้อื่น" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    assert_equal 2, Participation.active.where(user: @other).count
  end

  test "SUSP-06: event ที่กำลังรับราคา การเข้าร่วมถูกยกเลิกด้วย แต่ราคาที่ยื่นไว้แล้วไม่ถูกแตะ (SUSP-04)" do
    travel_to(@starts_at + 5.seconds) do
      assert PlaceBid.call(user: @user, lot: @lot_a, amount: 1_800).ok?
      @user.suspend!(by: @admin, reason: "ทดสอบ")
    end

    assert_equal 0, Participation.active.where(user: @user).count
    assert_equal 1, Bid.where(user: @user, lot: @lot_a).count, "ราคาที่ยื่นแล้วต้องยังอยู่ (ไม่ลบ ไม่ตัดสิทธิ์)"
  end

  test "SUSP-06: event ที่จบแล้วไม่ถูกแตะ (ประวัติการเข้าร่วม)" do
    travel_to(@starts_at + 31.seconds) { @event.reload.start!; @event.reload.settle! }
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    assert_equal 2, Participation.active.where(user: @user).count
  end

  test "SUSP-06: บันทึกจำนวนที่ยกเลิกใน audit log" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    log = AuditLog.where(action: "user.suspend", target_id: @user.id).last
    assert_equal 2, log.change_set["cancelled_participations"]
  end

  test "SUSP-03: ผู้ถูกระงับยื่นราคาไม่ได้ แม้เคยเข้าร่วมไว้" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    travel_to(@starts_at + 5.seconds) do
      assert_equal :suspended, PlaceBid.call(user: @user.reload, lot: @lot_a, amount: 1_800).error
    end
  end

  test "SUSP-07: ยกเลิกระงับแล้วต้องเข้าร่วมใหม่เอง (การเข้าร่วมเดิมไม่ถูกกู้คืน)" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    @user.unsuspend!(by: @admin, reason: "พ้นระงับ")

    assert_equal 0, Participation.active.where(user: @user).count
    assert Participation.create(user: @user.reload, lot: @lot_a).persisted?, "เข้าร่วมใหม่ได้ (ก่อนเริ่ม)"
  end

  test "SUSP-04/BID-17: ผู้ที่ถูกระงับระหว่างรับราคา ยังชนะได้ถ้าราคาสูงสุดและถึง reserve" do
    other_bid = nil
    travel_to(@starts_at + 5.seconds) do
      PlaceBid.call(user: @user, lot: @lot_a, amount: 2_500)
      other_bid = PlaceBid.call(user: @other, lot: @lot_a, amount: 1_800)
      @user.suspend!(by: @admin, reason: "ทดสอบ")
    end
    assert other_bid.ok?

    travel_to(@starts_at + 31.seconds) { @event.reload.settle! }

    assert_equal @user, @lot_a.reload.winning_bid.user
    assert_equal BigDecimal("2500"), @lot_a.winning_price
  end
end
