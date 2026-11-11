require "test_helper"

# กฎสำคัญต้องถูกบังคับที่ DB ด้วย ไม่ใช่แค่ validation ของ model (กันการเขียนข้าม model เช่น update_columns)
class DatabaseConstraintsTest < ActiveSupport::TestCase
  test "DB ไม่ยอมให้ราคาขั้นต่ำต่ำกว่าราคาเริ่มต้น" do
    assert_raises(ActiveRecord::CheckViolation) { items(:car).update_columns(reserve_price: 1) }
  end

  test "DB ไม่ยอมให้ราคาเริ่มต้นเป็น 0" do
    assert_raises(ActiveRecord::CheckViolation) { items(:car).update_columns(starting_price: 0) }
  end

  test "DB ไม่ยอมรับสถานะสินค้าที่ไม่รู้จัก" do
    assert_raises(ActiveRecord::CheckViolation) { Item.where(id: items(:car).id).update_all(status: "lost") }
  end

  test "DB ไม่ยอมให้ระยะเวลายื่นราคาเป็น 0" do
    assert_raises(ActiveRecord::CheckViolation) { auction_methods(:first_price).update_columns(bidding_seconds: 0) }
  end

  test "DB ไม่ยอมให้รหัสวิธีประมูลซ้ำ" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      AuctionMethod.insert_all!([ { code: "first_price", name: "ซ้ำ", bidding_seconds: 30 } ])
    end
  end

  test "DB ไม่ยอมให้จำนวนสูงสุดของห้องเป็น 0" do
    assert_raises(ActiveRecord::CheckViolation) { rooms(:main_hall).update_columns(max_participants: 0) }
    assert_raises(ActiveRecord::CheckViolation) { rooms(:main_hall).update_columns(max_items: 0) }
  end

  # --- event / lot (#53) ---

  test "DB ไม่ยอมให้สินค้าอยู่ใน lot ที่ยังไม่จบ 2 แห่ง (ITEM-10)" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Lot.insert_all!([ { auction_event_id: auction_events(:upcoming).id, item_id: items(:painting).id, status: "pending" } ])
    end
  end

  test "DB ไม่ยอมรับสถานะ event หรือ lot ที่ไม่รู้จัก" do
    assert_raises(ActiveRecord::CheckViolation) { AuctionEvent.where(id: auction_events(:upcoming).id).update_all(status: "lost") }
    assert_raises(ActiveRecord::CheckViolation) { Lot.where(id: lots(:upcoming_necklace).id).update_all(status: "lost") }
  end

  test "DB ไม่ยอมให้เวลาสิ้นสุดไม่หลังเวลาเริ่ม" do
    event = auction_events(:upcoming)
    assert_raises(ActiveRecord::CheckViolation) { event.update_columns(ends_at: event.starts_at) }
  end

  test "DB ไม่ยอมให้ lot ที่ขายได้ไม่มีราคาผู้ชนะ" do
    assert_raises(ActiveRecord::CheckViolation) { lots(:finished_lamp).update_columns(winning_price: nil) }
  end

  test "DB ไม่ยอมให้ลบห้อง/สินค้าที่ยังมี event หรือ lot อ้างถึง (NFR-19)" do
    assert_raises(ActiveRecord::InvalidForeignKey) { Room.where(id: rooms(:main_hall).id).delete_all }
    assert_raises(ActiveRecord::InvalidForeignKey) { Item.where(id: items(:lamp).id).delete_all }
    assert_raises(ActiveRecord::InvalidForeignKey) { AuctionEvent.where(id: auction_events(:finished).id).delete_all }
  end
end
