require "test_helper"

# #66/#67 BID-06..10, BID-14, BID-15, BID-16, BID-17, SUSP-04, SUSP-05, ITEM-11
# ตัวอย่างหลัก (requirements/04-bidding.md): สินค้า A ราคาเริ่มต้น 1,000 reserve 1,500
class AuctionEventSettlementTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    @method = auction_methods(:first_price)
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = create_event("รอบสรุปผล", [ item("A", 1_000, 1_500), item("B", 2_000, 3_000) ])
    @lot_a, @lot_b = @event.lots.order(:id).to_a
    @ana = bidder("5000")
    @bua = bidder("5000")
  end

  def item(name, start, reserve)
    Item.create!(name: name, description: "x", starting_price: start, reserve_price: reserve).tap { |i| i.approve!(by: @admin) }
  end

  def create_event(name, items)
    AuctionEvent.create!(name: name, room: rooms(:main_hall), auction_method: @method, starts_at: @starts_at,
                         ends_at: @starts_at + 2.hours, selected_item_ids: items.map(&:id))
  end

  def bidder(assets_value)
    create_approved_bidder(assets: [ { name: "บ้าน", value: assets_value } ], admin: @admin).tap do |user|
      @event.lots.each { |lot| Participation.create!(user: user, lot: lot) }
    end
  end

  def place(user, lot, amount, at: 5.seconds)
    travel_precisely(@starts_at + at) { PlaceBid.call(user: user, lot: lot, amount: amount) }.tap { |r| assert r.ok?, r.message }
  end

  def travel_precisely(time, &block) = travel_to(time, with_usec: true, &block)

  def settle(after: 31.seconds)
    travel_to(@starts_at + after) { @event.reload.start!; @event.reload.settle! }
  end

  # ---- ผู้ชนะ
  test "BID-06: ราคาสูงสุดชนะ จ่ายตามราคาที่ตนยื่น" do
    place(@ana, @lot_a, "1800")
    place(@bua, @lot_a, "2200")

    assert settle

    @lot_a.reload
    assert @lot_a.sold?
    assert_equal BigDecimal("2200"), @lot_a.winning_price
    assert_equal @bua, @lot_a.winning_bid.user
  end

  test "BID-07: ราคาเท่ากัน ผู้ยื่นก่อนชนะ (ตัวอย่างใน requirement: 10:00:05.200 ชนะ 10:00:09.700)" do
    late = place(@bua, @lot_a, "1800", at: 9.7.seconds).bid
    early = place(@ana, @lot_a, "1800", at: 5.2.seconds).bid

    settle

    assert_equal early, @lot_a.reload.winning_bid
    assert_not_equal late, @lot_a.winning_bid
    assert_equal BigDecimal("1800"), @lot_a.winning_price
  end

  test "ผู้ชนะแต่ละ lot คิดแยกกัน" do
    place(@ana, @lot_a, "1800")
    place(@bua, @lot_a, "1700")
    place(@bua, @lot_b, "4000")
    place(@ana, @lot_b, "3500")

    settle

    assert_equal @ana, @lot_a.reload.winning_bid.user
    assert_equal @bua, @lot_b.reload.winning_bid.user
  end

  # ---- BID-08 reserve
  test "BID-08: ราคาสูงสุดเท่ากับ reserve พอดี ขายได้ (ไม่ต่ำกว่า)" do
    place(@ana, @lot_a, "1500")
    settle
    assert @lot_a.reload.sold?
    assert_equal BigDecimal("1500"), @lot_a.winning_price
  end

  test "BID-08/BID-09: ราคาสูงสุดต่ำกว่า reserve ไม่ขาย (ตัวอย่าง: สูงสุด 1,400 ต่ำกว่า 1,500)" do
    place(@ana, @lot_a, "1400")
    place(@bua, @lot_a, "1100")

    settle

    @lot_a.reload
    assert @lot_a.unsold?
    assert_nil @lot_a.winning_price
    assert_nil @lot_a.winning_bid
  end

  test "BID-09: ไม่มีผู้ยื่นเลย ไม่ขาย" do
    settle
    assert @lot_a.reload.unsold?
    assert @lot_b.reload.unsold?
  end

  # ---- BID-10 / BID-09 / ITEM-11 สถานะสินค้า
  test "BID-10: ขายได้ สินค้าเป็น 'ขายได้แล้ว'" do
    place(@ana, @lot_a, "1800")
    settle
    assert @lot_a.item.reload.sold?
  end

  test "BID-09/ITEM-11: ไม่ขาย สินค้ากลับเป็น 'พร้อมขาย' และนำไปใส่ event ใหม่ได้" do
    settle
    assert @lot_a.item.reload.available?

    starts_at = Time.zone.now.change(usec: 0) + 1.day
    next_event = AuctionEvent.new(name: "รอบใหม่", room: rooms(:main_hall), auction_method: @method, starts_at: starts_at,
                                  ends_at: starts_at + 1.hour, selected_item_ids: [ @lot_a.item_id ])
    assert next_event.save, next_event.errors.full_messages.to_sentence
  end

  test "สินค้าที่ขายแล้วใส่ event ใหม่ไม่ได้" do
    place(@ana, @lot_a, "1800")
    settle
    starts_at = Time.zone.now.change(usec: 0) + 1.day
    next_event = AuctionEvent.new(name: "รอบใหม่", room: rooms(:main_hall), auction_method: @method, starts_at: starts_at,
                                  ends_at: starts_at + 1.hour, selected_item_ids: [ @lot_a.item_id ])
    assert_not next_event.save
  end

  test "ประวัติ lot ที่ไม่ขายยังอยู่ (สถานะ unsold) และราคาที่ยื่นไม่ถูกลบ" do
    place(@ana, @lot_a, "1100")
    settle
    assert_equal 1, Lot.where(id: @lot_a.id, status: "unsold").count
    assert_equal 1, @lot_a.bids.count
  end

  # ---- BID-16 / event
  test "สรุปผลทุก lot พร้อมกัน แล้ว event เป็น 'สรุปผลแล้ว' พร้อมเวลาที่สรุป" do
    place(@ana, @lot_a, "1800")
    assert settle

    @event.reload
    assert @event.settled?
    assert_not_nil @event.settled_at
    assert_equal [ "sold", "unsold" ], @event.lots.order(:id).pluck(:status)
  end

  test "BID-17/SUSP-04: ราคาของผู้ที่ถูกระงับภายหลังนับตามปกติ ผู้ถูกระงับยังชนะได้" do
    place(@ana, @lot_a, "2500")
    place(@bua, @lot_a, "1800")
    travel_to(@starts_at + 10.seconds) { @ana.suspend!(by: @admin, reason: "ทดสอบ") }

    settle

    assert_equal @ana, @lot_a.reload.winning_bid.user
  end

  test "SUSP-05: ระงับผู้ชนะหลังสรุปผลแล้ว ผลไม่เปลี่ยน" do
    place(@ana, @lot_a, "2500")
    settle
    before = @lot_a.reload.attributes

    @ana.suspend!(by: @admin, reason: "ทดสอบ")
    travel_to(@starts_at + 1.hour) { @event.reload.settle! }

    assert_equal before, @lot_a.reload.attributes
  end

  # ---- BID-14 รันซ้ำได้ผลเดิม / เงื่อนไขเวลา
  test "BID-14: สรุปผลซ้ำได้ผลเดิม ไม่เปลี่ยนผู้ชนะ สถานะ หรือเวลาที่สรุป" do
    place(@ana, @lot_a, "1800")
    assert settle
    snapshot = [ @event.reload.attributes, @lot_a.reload.attributes, @lot_a.item.reload.attributes ]

    travel_to(@starts_at + 5.minutes) do
      assert_equal false, @event.reload.settle!
      assert_equal false, @event.reload.settle!
    end

    assert_equal snapshot, [ @event.reload.attributes, @lot_a.reload.attributes, @lot_a.item.reload.attributes ]
  end

  test "ก่อนหมดเวลายื่น (รวมที่เส้นตายพอดี) สรุปผลไม่ได้ ไม่ทำอะไร" do
    place(@ana, @lot_a, "1800")
    travel_to(@starts_at + 5.seconds) { @event.reload.start! }

    [ 6.seconds, 30.seconds ].each do |after|
      travel_to(@starts_at + after) { assert_equal false, @event.reload.settle! }
    end

    assert @event.reload.bidding?
    assert @lot_a.reload.pending?
  end

  test "เลยเส้นตายแม้เสี้ยววินาที สรุปผลได้" do
    place(@ana, @lot_a, "1800")
    travel_to(@starts_at) { @event.reload.start! }
    travel_to(@starts_at + 30.seconds + 0.001.seconds, with_usec: true) { assert @event.reload.settle! }
  end

  test "event ที่ยังไม่เริ่มหรือถูกยกเลิก สรุปผลไม่ได้" do
    travel_to(@starts_at + 1.hour) { assert_equal false, @event.reload.settle! }
    @event.cancel!
    travel_to(@starts_at + 1.hour) { assert_equal false, @event.reload.settle! }
    assert @event.reload.cancelled?
  end

  test "ใช้ระยะเวลายื่นราคาจากวิธีประมูลของ event (ไม่ฝัง 30 วินาที)" do
    @method.update!(bidding_seconds: 10)
    place(@ana, @lot_a, "1800", at: 5.seconds)
    travel_to(@starts_at + 11.seconds) { @event.reload.start!; assert @event.reload.settle! }
    assert @lot_a.reload.sold?
  end

  test "ถ้าสรุปผล lot ใดพัง ทั้งรอบถูก rollback (ไม่ค้างครึ่งๆ กลางๆ)" do
    place(@ana, @lot_a, "1800")
    travel_to(@starts_at + 31.seconds) do
      @event.reload.start!
      original = Item.instance_method(:update!)
      Item.class_eval { define_method(:update!) { |*| raise ActiveRecord::RecordInvalid } }
      begin
        assert_raises(ActiveRecord::RecordInvalid) { @event.reload.settle! }
      ensure
        Item.class_eval { define_method(:update!, original) }
      end
    end

    assert @event.reload.bidding?
    assert @lot_a.reload.pending?
  end

  # ---- due_to_settle
  test "due_to_settle: เฉพาะ event ที่เปิดรับราคาและเลยเวลาปิดรับแล้ว" do
    travel_to(@starts_at) { @event.reload.start! }

    # (event ตัวอย่างอื่นในฟิกซ์เจอร์ก็อาจเลยเวลาแล้ว จึงตรวจเฉพาะ event ของ test นี้)
    travel_to(@starts_at + 30.seconds) { assert_not_includes AuctionEvent.due_to_settle, @event }
    travel_to(@starts_at + 31.seconds) { assert_includes AuctionEvent.due_to_settle, @event }

    travel_to(@starts_at + 31.seconds) { @event.reload.settle! }
    travel_to(@starts_at + 31.seconds) { assert_not_includes AuctionEvent.due_to_settle, @event } # สรุปแล้วไม่ถูกหยิบซ้ำ
  end
end
