require "test_helper"

# #54 (แก้รายการสินค้าของ event) ชนกับ #59 (participations): lot ที่มีประวัติการเข้าร่วมลบไม่ได้ (NFR-19)
# เอาสินค้าออกจึงต้องยกเลิกการเข้าร่วมที่ค้างอยู่แล้วตั้ง lot เป็น cancelled ไม่ใช่ลบ
class AuctionEventParticipantsTest < ActiveSupport::TestCase
  setup do
    @event = auction_events(:upcoming) # มี lot ของ สร้อยคอทองคำ
    @lot = lots(:upcoming_necklace)
    @user = create_approved_bidder
  end

  test "เอาสินค้าออกจาก event ที่ไม่มีใครเข้าร่วม: ลบ lot ตามเดิม" do
    assert @event.update(selected_item_ids: [ items(:car).id ])
    assert_not Lot.exists?(@lot.id)
  end

  test "เอาสินค้าออกจาก event ที่มีคนเข้าร่วมแล้ว: ไม่พัง lot เป็น cancelled และเก็บแถวเข้าร่วมเป็นประวัติ" do
    participation = Participation.create!(user: @user, lot: @lot)
    assert @event.update(selected_item_ids: [ items(:car).id ]), @event.errors.full_messages.to_sentence

    assert_equal "cancelled", @lot.reload.status
    assert Participation.exists?(participation.id), "แถวเข้าร่วมเป็นประวัติ ห้ามลบ (NFR-19)"
    assert_not participation.reload.active?, "การเข้าร่วมที่ค้างอยู่ถูกยกเลิก"
    assert_equal [ items(:car) ], @event.reload.items.merge(Lot.pending).to_a
  end

  test "คืนที่นั่งเมื่อเอาสินค้าออก" do
    room = @event.room
    room.update!(max_participants: 1)
    Participation.create!(user: @user, lot: @lot)
    assert Participation.full?(@event)

    @event.update!(selected_item_ids: [ items(:car).id ])
    assert_not Participation.full?(@event.reload)
    assert_equal 0, Participation.participants_count(@event)
  end

  test "การเข้าร่วมของ lot อื่นใน event เดียวกันไม่กระทบ" do
    stay_lot = Lot.create!(auction_event: @event, item: items(:car))
    stay = Participation.create!(user: @user, lot: stay_lot)
    Participation.create!(user: create_approved_bidder, lot: @lot)

    @event.update!(selected_item_ids: [ items(:car).id ])
    assert stay.reload.active?
    assert_equal "pending", stay_lot.reload.status
  end

  test "ใส่สินค้าที่เคยเอาออกกลับมา: ใช้ lot เดิมกลับเป็น pending และผู้ที่เคยเข้าร่วมต้องเข้าร่วมใหม่" do
    old = Participation.create!(user: @user, lot: @lot)
    @event.update!(selected_item_ids: [ items(:car).id ])

    assert @event.update(selected_item_ids: [ items(:necklace).id ]), @event.errors.full_messages.to_sentence
    assert_equal "pending", @lot.reload.status
    assert_equal 1, @event.lots.where(item: items(:necklace)).count, "ใช้ lot เดิม ไม่สร้างซ้ำ (unique index)"
    assert_not old.reload.active?, "ผู้ที่เคยเข้าร่วมไม่ได้กลับมาเป็นผู้เข้าร่วมเอง"
    assert Participation.create(user: @user, lot: @lot).persisted?, "เข้าร่วมใหม่ได้"
  end

  test "EVT-08 event ที่เริ่มแล้วแก้สินค้าไม่ได้ และไม่แตะการเข้าร่วม" do
    live = auction_events(:live)
    live.update_columns(starts_at: 1.hour.from_now, status: "scheduled") # ให้เข้าร่วมได้ก่อน แล้วค่อยเริ่ม
    painting_lot = lots(:live_painting)
    participation = Participation.create!(user: @user, lot: painting_lot)
    live.update_columns(status: "bidding")
    assert_not live.update(selected_item_ids: [ items(:car).id ])
    assert participation.reload.active?
  end
end
