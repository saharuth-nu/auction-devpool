require "test_helper"

class AuctionEventTest < ActiveSupport::TestCase
  def build(**attrs)
    starts_at = 2.days.from_now
    AuctionEvent.new({
      name: "ประมูลทดสอบ",
      room: rooms(:main_hall),
      auction_method: auction_methods(:first_price),
      starts_at: starts_at,
      ends_at: starts_at + 1.hour
    }.merge(attrs))
  end

  # --- ข้อมูลและสถานะเริ่มต้น (EVT-02, EVT-10) ---

  test "ข้อมูลครบบันทึกได้ และเริ่มที่สถานะยังไม่เริ่ม (EVT-02, EVT-10)" do
    event = build
    assert event.save
    assert event.scheduled?
  end

  test "ต้องมีชื่อ ห้อง วิธีประมูล เวลาเริ่ม และเวลาสิ้นสุด (EVT-02)" do
    %i[name room auction_method starts_at ends_at].each do |attribute|
      event = build(attribute => nil)
      assert_not event.valid?, "#{attribute} ว่างต้องไม่ผ่าน"
      assert event.errors.key?(attribute), "ต้องมี error ที่ #{attribute}"
    end
  end

  # --- เวลา (EVT-05, EVT-06) ---

  test "เวลาสิ้นสุดเร็วกว่าเวลาเริ่ม + ระยะเวลายื่นราคาไม่ได้ (EVT-05)" do
    starts_at = 2.days.from_now
    event = build(starts_at: starts_at, ends_at: starts_at + 29.seconds)
    assert_not event.valid?
    assert event.errors.of_kind?(:ends_at, :before_bidding_window)

    assert build(starts_at: starts_at, ends_at: starts_at + 30.seconds).valid?
  end

  test "ระยะเวลาขั้นต่ำมาจากวิธีประมูล ไม่ได้ฝังตัวเลข (METH-07)" do
    starts_at = 2.days.from_now
    event = build(auction_method: auction_methods(:english), starts_at: starts_at, ends_at: starts_at + 45.seconds)
    assert_not event.valid?
    assert event.errors.of_kind?(:ends_at, :before_bidding_window), "english ใช้ 60 วินาที จึงสิ้นสุดที่ 45 วินาทีไม่ได้"
  end

  test "ปิดรับราคาเมื่อครบระยะเวลาของวิธีประมูลนับจากเวลาเริ่ม ไม่ใช่ ends_at (EVT-06)" do
    event = auction_events(:upcoming)
    assert_equal event.starts_at + 30.seconds, event.bidding_ends_at
    assert_operator event.bidding_ends_at, :<, event.ends_at
  end

  # --- การเปลี่ยนสถานะ (EVT-10) ---

  test "เปลี่ยนสถานะตามลำดับ ยังไม่เริ่ม → เปิดรับราคา → สรุปผลแล้ว (EVT-10)" do
    event = auction_events(:upcoming)
    event.transition_to!(:bidding)
    assert event.reload.bidding?
    event.transition_to!(:settled, settled_at: Time.current)
    assert event.reload.settled?
    assert event.finished?
  end

  test "ข้ามขั้นหรือย้อนสถานะไม่ได้ (EVT-10)" do
    assert_raises(AuctionEvent::InvalidTransition) { auction_events(:upcoming).transition_to!(:settled) }
    assert_raises(AuctionEvent::InvalidTransition) { auction_events(:live).transition_to!(:scheduled) }
    assert_raises(AuctionEvent::InvalidTransition) { auction_events(:finished).transition_to!(:bidding) }
  end

  test "แก้ status ตรงๆ ข้ามขั้นก็ไม่ผ่าน validation" do
    event = auction_events(:upcoming)
    assert_not event.update(status: :settled)
    assert event.errors.of_kind?(:status, :invalid_transition)
  end

  # --- ยกเลิก (EVT-08) ---

  test "ยกเลิกก่อนเริ่มได้ และปล่อยสินค้าออกจาก event (EVT-08, ITEM-10)" do
    event = auction_events(:upcoming)
    event.cancel!

    assert event.reload.cancelled?
    assert_not_nil event.cancelled_at
    assert lots(:upcoming_necklace).reload.cancelled?
  end

  test "ยกเลิก event ที่เริ่มแล้วไม่ได้ (EVT-08)" do
    assert_raises(AuctionEvent::InvalidTransition) { auction_events(:live).cancel! }
    assert lots(:live_painting).reload.pending?
  end

  # --- ล็อกหลังเริ่ม (EVT-08) ---

  test "ก่อนเริ่มแก้เวลา ห้อง และวิธีประมูลได้ (EVT-08)" do
    event = auction_events(:upcoming)
    other_room = Room.create!(name: "ห้องเล็ก", max_participants: 5, max_items: 3)
    assert event.update(starts_at: event.starts_at + 1.hour, ends_at: event.ends_at + 1.hour, room: other_room)
    assert event.editable?
  end

  test "เริ่มแล้วแก้เวลาและห้องไม่ได้ แต่แก้ชื่อได้ (EVT-08)" do
    event = auction_events(:live)
    assert_not event.editable?
    assert_not event.update(ends_at: event.ends_at + 1.hour)
    assert event.errors.of_kind?(:ends_at, :locked_after_start)
    assert_not event.update(room: Room.create!(name: "ห้องเล็ก", max_participants: 5, max_items: 3))

    assert event.reload.update(name: "ชื่อใหม่")
  end

  # --- ลบ (EVT-08, NFR-19) ---

  test "ลบ event ที่ยังไม่เริ่มได้ พร้อม lot ของมัน (EVT-08)" do
    event = auction_events(:upcoming)
    lot_id = lots(:upcoming_necklace).id
    assert event.destroy
    assert_not Lot.exists?(lot_id)
  end

  test "ลบ event ที่เริ่มแล้วหรือจบแล้วไม่ได้ และ lot ยังอยู่ (EVT-08, NFR-19)" do
    %i[live finished].each do |name|
      event = auction_events(name)
      assert_not event.destroy, "#{name} ต้องลบไม่ได้"
      assert AuctionEvent.exists?(event.id)
    end
    assert Lot.exists?(lots(:live_painting).id)
    assert Lot.exists?(lots(:finished_lamp).id)
  end

  test "ลบห้อง วิธีประมูล หรือสินค้าที่มี event อ้างถึงไม่ได้ (NFR-19)" do
    assert_not rooms(:main_hall).destroy
    assert_not auction_methods(:first_price).destroy
    assert_not items(:lamp).destroy
  end

  test "event ที่ยังไม่จบคือยังไม่เริ่มและเปิดรับราคา" do
    assert_equal %w[live upcoming].sort,
      AuctionEvent.unfinished.map { |e| e == auction_events(:live) ? "live" : "upcoming" }.sort
    assert_not_includes AuctionEvent.unfinished, auction_events(:finished)
  end

  # --- สร้าง/เลือกสินค้า (#54: EVT-02/03/04, METH-06, ROOM-05) ---

  test "สร้างพร้อมเลือกสินค้าแล้วได้ lot ตามที่เลือก (EVT-02)" do
    event = build(selected_item_ids: [ items(:car).id ])
    assert event.save, event.errors.full_messages.to_sentence
    assert_equal [ items(:car) ], event.items.to_a
    assert event.lots.all?(&:pending?)
  end

  test "ต้องเลือกสินค้าอย่างน้อย 1 ชิ้น (EVT-02)" do
    event = build(selected_item_ids: [])
    assert_not event.valid?
    assert event.errors.of_kind?(:selected_item_ids, :blank)
  end

  test "จำนวนสินค้าต้องไม่เกินที่ห้องรองรับ (EVT-03)" do
    small = Room.create!(name: "ห้องจิ๋ว", max_participants: 5, max_items: 1)
    extra = Item.create!(name: "ชิ้นที่สอง", starting_price: 100, reserve_price: 100, status: :available)
    event = build(room: small, selected_item_ids: [ items(:car).id, extra.id ])
    assert_not event.valid?
    assert event.errors.of_kind?(:selected_item_ids, :too_many)
  end

  test "เลือกได้เฉพาะสินค้าพร้อมขาย ไม่เก็บถาวร และไม่อยู่ใน event อื่นที่ยังไม่จบ (EVT-04)" do
    [ :watch, :vase, :painting, :necklace, :lamp ].each do |name| # รออนุมัติ / เก็บถาวร / อยู่ใน event อื่น x2 / ขายแล้ว
      event = build(selected_item_ids: [ items(name).id ])
      assert_not event.valid?, "#{name} ต้องเลือกไม่ได้"
      assert event.errors.of_kind?(:selected_item_ids, :not_selectable)
    end
  end

  test "รายการสินค้าที่เลือกได้รวมสินค้าที่อยู่ใน event นี้อยู่แล้ว (EVT-04)" do
    selectable = auction_events(:upcoming).selectable_items
    assert_includes selectable, items(:necklace)
    assert_includes selectable, items(:car)
    assert_not_includes selectable, items(:painting)
    assert_not_includes AuctionEvent.new.selectable_items, items(:necklace)
  end

  test "แก้รายการสินค้าก่อนเริ่ม: เพิ่มและเอาออกได้ (EVT-01)" do
    event = auction_events(:upcoming)
    necklace_lot_id = lots(:upcoming_necklace).id
    assert event.update(selected_item_ids: [ items(:car).id ])
    assert_equal [ items(:car) ], event.reload.items.to_a
    assert_not Lot.exists?(necklace_lot_id)
  end

  test "เริ่มแล้วแก้รายการสินค้าไม่ได้ (EVT-08)" do
    event = auction_events(:live)
    assert_not event.update(selected_item_ids: [ items(:car).id ])
    assert event.errors.of_kind?(:selected_item_ids, :locked_after_start)
  end

  test "เวลาเริ่มต้องอยู่ในอนาคตตอนสร้าง" do
    event = build(starts_at: 1.minute.ago, ends_at: 1.hour.from_now)
    assert_not event.valid?
    assert event.errors.of_kind?(:starts_at, :in_past)
  end

  test "วิธีประมูลที่ปิดใช้งานหรือยังไม่มีกติกาเลือกตอนสร้างไม่ได้ แต่ event เดิมไม่กระทบ (METH-06)" do
    event = build(auction_method: auction_methods(:english), ends_at: 2.days.from_now + 1.hour)
    assert_not event.valid?
    assert event.errors.of_kind?(:auction_method, :not_selectable)

    auction_methods(:first_price).disable!
    assert_not build.valid?
    existing = auction_events(:upcoming)
    assert existing.update(name: "เปลี่ยนชื่อได้"), existing.errors.full_messages.to_sentence
  end

  test "ห้องที่เก็บถาวรเลือกใส่ event ใหม่ไม่ได้ (ROOM-05)" do
    event = build(room: rooms(:old_room))
    assert_not event.valid?
    assert event.errors.of_kind?(:room, :archived)
  end

  # --- เริ่มการประมูล (#55 EVT-07) ---

  test "ถึงเวลาเริ่ม: event เป็นเปิดรับราคา และสินค้าเป็นอยู่ระหว่างการประมูล (EVT-07)" do
    event = auction_events(:upcoming)
    travel_to event.starts_at do
      assert event.start!
    end
    assert event.reload.bidding?
    assert items(:necklace).reload.in_auction?
    assert lots(:upcoming_necklace).reload.pending?
  end

  test "สินค้าทุกชิ้นใน event เริ่มพร้อมกัน (BID-16)" do
    event = auction_events(:upcoming)
    event.update!(selected_item_ids: [ items(:necklace).id, items(:car).id ])
    travel_to(event.starts_at) { event.start! }
    assert items(:necklace).reload.in_auction?
    assert items(:car).reload.in_auction?
  end

  test "ยังไม่ถึงเวลาไม่เริ่ม (NFR-03)" do
    event = auction_events(:upcoming)
    travel_to event.starts_at - 1.second do
      assert_not event.start!
    end
    assert event.reload.scheduled?
    assert items(:necklace).reload.available?
  end

  test "เริ่มซ้ำได้ผลเดิม ไม่ error (EVT-07 ทำซ้ำได้)" do
    event = auction_events(:upcoming)
    travel_to event.starts_at + 1.second do
      assert event.start!
      assert_not event.start!
      assert_not AuctionEvent.find(event.id).start!
    end
    assert event.reload.bidding?
  end

  test "event ที่ยกเลิกแล้วไม่เริ่ม และสินค้าไม่ถูกล็อก" do
    event = auction_events(:upcoming)
    event.cancel!
    travel_to(event.starts_at) { assert_not event.start! }
    assert event.reload.cancelled?
    assert items(:necklace).reload.available?
  end

  test "สินค้าที่ไม่พร้อมขายแล้วตอนเริ่ม ถูกถอนออกจากรอบนี้" do
    event = auction_events(:upcoming)
    event.update!(selected_item_ids: [ items(:necklace).id, items(:car).id ])
    items(:car).archive!
    travel_to(event.starts_at) { event.start! }

    assert items(:necklace).reload.in_auction?
    assert items(:car).reload.available?, "สินค้าที่ถูกถอนไม่เปลี่ยนสถานะ"
    assert event.lots.find_by(item: items(:car)).cancelled?
  end

  test "เริ่มแล้วยกเลิกไม่ได้" do
    event = auction_events(:upcoming)
    travel_to(event.starts_at) { event.start! }
    assert_raises(AuctionEvent::InvalidTransition) { event.reload.cancel! }
  end
end
