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
    assert_not event.valid?, "english ใช้ 60 วินาที จึงสิ้นสุดที่ 45 วินาทีไม่ได้"
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
    assert event.update(starts_at: event.starts_at + 1.hour, ends_at: event.ends_at + 1.hour, room: rooms(:old_room))
    assert event.editable?
  end

  test "เริ่มแล้วแก้เวลาและห้องไม่ได้ แต่แก้ชื่อได้ (EVT-08)" do
    event = auction_events(:live)
    assert_not event.editable?
    assert_not event.update(ends_at: event.ends_at + 1.hour)
    assert event.errors.of_kind?(:ends_at, :locked_after_start)
    assert_not event.update(room: rooms(:old_room))

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
end
