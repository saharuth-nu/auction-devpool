# lot ที่ขายได้ชี้ไปที่ราคาที่ชนะ (สาย D เว้นไว้ใน CreateLots: "winning_bid_id จะเพิ่มพร้อมตาราง bids")
# ราคาที่ชนะผูกกับ bid ได้แถวเดียว และลบ bid ที่เป็นผู้ชนะไม่ได้ (restrict)
class AddWinningBidToLots < ActiveRecord::Migration[8.1]
  def change
    add_reference :lots, :winning_bid, null: true, index: { unique: true },
                  foreign_key: { to_table: :bids, on_delete: :restrict }
  end
end
