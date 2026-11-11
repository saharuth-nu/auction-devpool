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
end
