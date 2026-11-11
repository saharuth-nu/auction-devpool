require "test_helper"

# USR-06 (ครั้งเดียวต่อสินค้า, ยกเลิกได้ก่อนเริ่ม), USR-07 (ห้องเต็มนับเป็น "คน"), NFR-19 (ยกเลิกแล้วไม่ลบแถว)
class ParticipationTest < ActiveSupport::TestCase
  # event ใหม่ในห้องที่กำหนดจำนวนคนเอง · เริ่มพรุ่งนี้ วิธีประมูล first_price (30 วินาที)
  def build_event(max_participants: 2, lots: 1, starts_at: 1.day.from_now.change(usec: 0))
    room = Room.create!(name: "ห้องทดสอบ #{SecureRandom.hex(3)}", max_participants:, max_items: 10)
    event = AuctionEvent.create!(name: "ทดสอบ", room:, auction_method: auction_methods(:first_price),
                                 starts_at:, ends_at: starts_at + 1.hour)
    lots = Array.new(lots) do |i|
      item = Item.create!(name: "สินค้า #{i}", starting_price: 100, reserve_price: 100, status: :available)
      Lot.create!(auction_event: event, item:)
    end
    [ event, *lots ]
  end

  def join(user, lot) = Participation.create(user:, lot:)

  def join!(user, lot) = Participation.create!(user:, lot:)

  # ---------- เข้าร่วม ----------

  test "USR-05 ผู้ประมูลที่ผ่านการตรวจเข้าร่วมสินค้าที่ยังไม่เริ่มได้" do
    _event, lot = build_event
    participation = join(create_approved_bidder, lot)
    assert participation.persisted?
    assert participation.active?
  end

  test "USR-06 เข้าร่วมสินค้าเดียวกันซ้ำไม่ได้" do
    _event, lot = build_event
    user = create_approved_bidder
    join!(user, lot)
    again = join(user, lot)
    assert_not again.persisted?
    assert_includes again.errors.map(&:message), "คุณเข้าร่วมสินค้านี้แล้ว"
  end

  test "USR-06 DB บังคับ unique ของแถวที่ยังไม่ยกเลิก แม้ข้าม validation" do
    _event, lot = build_event
    user = create_approved_bidder
    join!(user, lot)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Participation.insert_all!([ { user_id: user.id, lot_id: lot.id, created_at: Time.current, updated_at: Time.current } ])
    end
  end

  test "USR-06 ผู้ใช้คนละคนเข้าร่วมสินค้าเดียวกันได้" do
    _event, lot = build_event
    assert join(create_approved_bidder, lot).persisted?
    assert join(create_approved_bidder, lot).persisted?
  end

  # ---------- ยกเลิก ----------

  test "USR-06 ยกเลิกก่อนเริ่ม: ใส่ cancelled_at ไม่ลบแถว (NFR-19) แล้วเข้าร่วมใหม่ได้ เกิดแถวใหม่" do
    _event, lot = build_event
    user = create_approved_bidder
    first = join!(user, lot)
    first.cancel!
    assert_not first.reload.active?
    assert_not_nil first.cancelled_at

    second = join!(user, lot)
    assert_not_equal first.id, second.id
    assert_equal [ 1, 1 ], [ Participation.active.where(user:, lot:).count, Participation.cancelled.where(user:, lot:).count ]
  end

  test "USR-06 ยกเลิกหลังเริ่มประมูลไม่ได้ (ถึงเวลาเริ่มพอดีก็ไม่ได้)" do
    event, lot = build_event
    participation = join!(create_approved_bidder, lot)
    travel_to event.starts_at - 1.second do
      assert participation.cancellable?
    end
    travel_to event.starts_at do
      assert_not participation.cancellable?
      assert_raises(Participation::NotCancellable) { participation.cancel! }
    end
    assert participation.reload.active?
  end

  test "ยกเลิกซ้ำไม่ได้" do
    _event, lot = build_event
    participation = join!(create_approved_bidder, lot)
    participation.cancel!
    assert_raises(Participation::NotCancellable) { participation.cancel! }
  end

  # ---------- USR-07: ห้องเต็ม ----------

  test "USR-07 ห้องเต็มแล้วคนใหม่เข้าร่วมไม่ได้ พร้อมข้อความ เต็มแล้ว" do
    event, lot = build_event(max_participants: 2)
    join!(create_approved_bidder, lot)
    join!(create_approved_bidder, lot)
    assert Participation.full?(event)

    third = join(create_approved_bidder, lot)
    assert_not third.persisted?
    assert_includes third.errors.map(&:message), "เต็มแล้ว"
  end

  test "USR-07 มีคนยกเลิกแล้วที่นั่งว่างให้คนอื่น" do
    event, lot = build_event(max_participants: 1)
    first = join!(create_approved_bidder, lot)
    assert_not join(create_approved_bidder, lot).persisted?
    first.cancel!
    assert_not Participation.full?(event)
    assert join(create_approved_bidder, lot).persisted?
  end

  test "USR-07 นับเป็นจำนวนคน ไม่ใช่จำนวนสินค้า: คนเดิมเข้าร่วมสินค้าเพิ่มได้แม้ห้องเต็ม" do
    event, lot_a, lot_b = build_event(max_participants: 1, lots: 2)
    member = create_approved_bidder
    join!(member, lot_a)
    assert Participation.full?(event)
    assert_equal 1, Participation.participants_count(event)

    assert join(member, lot_b).persisted?, "คนที่อยู่ใน event แล้วเข้าร่วมสินค้าอื่นได้"
    assert_equal 1, Participation.participants_count(event)
    assert_not join(create_approved_bidder, lot_b).persisted?, "คนใหม่ยังเข้าไม่ได้"
  end

  test "USR-07 ยกเลิกสินค้าหนึ่งแต่ยังเหลืออีกชิ้น ที่นั่งยังอยู่ ยกเลิกหมดที่นั่งจึงว่าง" do
    event, lot_a, lot_b = build_event(max_participants: 1, lots: 2)
    member = create_approved_bidder
    first = join!(member, lot_a)
    second = join!(member, lot_b)
    first.cancel!
    assert_equal 1, Participation.participants_count(event)
    second.cancel!
    assert_equal 0, Participation.participants_count(event)
  end

  test "USR-07 นับแยกตาม event: event อื่นของห้องเดียวกันไม่ปนกัน" do
    event, lot = build_event(max_participants: 1)
    other_event, other_lot = build_event(max_participants: 1)
    join!(create_approved_bidder, lot)
    assert_equal 0, Participation.participants_count(other_event)
    assert join(create_approved_bidder, other_lot).persisted?
    assert_equal 1, Participation.participants_count(event)
  end

  test "USR-07 lot ที่ถูกยกเลิก (เอาสินค้าออกจาก event) ไม่ถือที่นั่ง แม้แถวเข้าร่วมยังอยู่เป็นประวัติ" do
    event, lot_a, lot_b = build_event(max_participants: 1, lots: 2)
    member = create_approved_bidder
    join!(member, lot_a)
    assert Participation.full?(event)

    lot_a.update!(status: :cancelled)
    assert_equal 1, Participation.where(lot: lot_a).active.count, "แถวเข้าร่วมเป็นประวัติ ไม่ถูกลบ (NFR-19)"
    assert_equal 0, Participation.participants_count(event)
    assert_not Participation.full?(event)
    assert join(create_approved_bidder, lot_b).persisted?, "ที่นั่งว่างให้คนอื่นแล้ว"
  end

  test "ROOM-04 lot ที่ถูกยกเลิกไม่ถูกนับว่าใช้ที่นั่งของห้อง" do
    event, lot = build_event(max_participants: 2)
    join!(create_approved_bidder, lot)
    join!(create_approved_bidder, lot)
    lot.update!(status: :cancelled)
    assert_equal 0, event.room.max_participants_in_use
  end

  # ---------- ใครเข้าร่วมได้ ----------

  test "QUAL-05 ผู้ใช้ที่ยังไม่ผ่านการตรวจคุณสมบัติเข้าร่วมไม่ได้" do
    _event, lot = build_event
    result = join(create_bidder, lot)
    assert_not result.persisted?
    assert_includes result.errors.map(&:message), "ต้องผ่านการตรวจสอบคุณสมบัติก่อน"
  end

  test "SUSP-03 ผู้ใช้ที่ถูกระงับเข้าร่วมไม่ได้" do
    _event, lot = build_event
    user = create_approved_bidder
    user.update_columns(suspended_at: Time.current)
    result = join(user, lot)
    assert_not result.persisted?
    assert_includes result.errors.map(&:message), "บัญชีถูกระงับ เข้าร่วมประมูลไม่ได้"
  end

  test "admin เข้าร่วมประมูลไม่ได้" do
    _event, lot = build_event
    assert_not join(create_admin, lot).persisted?
  end

  # ---------- สินค้าที่เข้าร่วมได้ ----------

  test "O-8 เข้าร่วมได้จนปิดรับราคา: หลังเริ่มแล้วยังได้ ครบเวลาพอดียังได้ เกินไปไม่ได้" do
    event, lot = build_event
    user = create_approved_bidder
    travel_to(event.starts_at + 5.seconds) { assert join(user, lot).persisted? }
    travel_to(event.bidding_ends_at) { assert join(create_approved_bidder, lot).persisted? }
    travel_to(event.bidding_ends_at + 1.second) do
      closed = join(create_approved_bidder, lot)
      assert_not closed.persisted?
      assert_includes closed.errors.map(&:message), "สินค้านี้ปิดรับการเข้าร่วมแล้ว"
    end
  end

  test "สินค้าที่ผู้ใช้มองไม่เห็น (event ยกเลิก, lot ไม่ pending, สินค้าเก็บถาวร) เข้าร่วมไม่ได้" do
    _event, lot = build_event
    user = create_approved_bidder
    lot.update!(status: :unsold)
    assert_not join(user, lot).persisted?
    lot.update!(status: :pending)

    lot.item.archive!
    assert_not join(user, lot).persisted?

    event2, lot2 = build_event
    event2.cancel!
    assert_not join(user, lot2.reload).persisted?
  end

  # ---------- NFR-19 ----------

  test "NFR-19 DB ไม่ยอมให้ลบผู้ใช้หรือ lot ที่มีการเข้าร่วมอ้างถึง" do
    _event, lot = build_event
    user = create_approved_bidder
    join!(user, lot)
    assert_raises(ActiveRecord::InvalidForeignKey) { Lot.where(id: lot.id).delete_all }
    assert_raises(ActiveRecord::InvalidForeignKey) { User.where(id: user.id).delete_all }
  end

  # ---------- ROOM-04 ----------

  test "ROOM-04 ลดจำนวนผู้เข้าร่วมสูงสุดต่ำกว่าคนที่เข้าร่วมอยู่ใน event ที่ยังไม่จบไม่ได้" do
    event, lot = build_event(max_participants: 3)
    3.times { join!(create_approved_bidder, lot) }
    room = event.room
    assert_equal 3, room.max_participants_in_use

    room.max_participants = 2
    assert_not room.valid?
    assert_match "มีอยู่ 3 คน", room.errors[:max_participants].first
    room.max_participants = 3
    assert room.valid?
  end

  test "ROOM-04 คนที่ยกเลิกแล้วและ event ที่จบแล้วไม่ถูกนับ" do
    event, lot = build_event(max_participants: 3)
    join!(create_approved_bidder, lot)
    leaver = join!(create_approved_bidder, lot)
    leaver.cancel!
    room = event.room
    assert_equal 1, room.max_participants_in_use
    room.max_participants = 1
    assert room.valid?

    event.update_columns(status: "settled") # จบแล้ว ไม่ผูกห้อง
    assert_equal 0, room.max_participants_in_use
  end
end
