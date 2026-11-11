class CreateLots < ActiveRecord::Migration[8.1]
  def change
    # lot = สินค้าหนึ่งชิ้นใน event หนึ่ง เก็บผลของชิ้นนั้น (ห้ามลบเมื่อมีประวัติ NFR-19)
    create_table :lots do |t|
      t.references :auction_event, null: false, foreign_key: { on_delete: :restrict }
      t.references :item, null: false, foreign_key: { on_delete: :restrict }
      # pending = ยังไม่จบ · sold/unsold = ผลหลังปิด · cancelled = event ถูกยกเลิก
      t.string :status, null: false, default: "pending"
      # winning_bid_id จะเพิ่มพร้อมตาราง bids (#63)
      t.decimal :winning_price, precision: 15, scale: 2

      t.timestamps
      t.check_constraint "status IN ('pending', 'sold', 'unsold', 'cancelled')", name: "lots_status_valid"
      t.check_constraint "winning_price IS NULL OR winning_price > 0", name: "lots_winning_price_positive"
      t.check_constraint "status <> 'sold' OR winning_price IS NOT NULL", name: "lots_sold_has_winning_price"
    end
    add_index :lots, %i[auction_event_id item_id], unique: true
    # สินค้าอยู่ได้ event เดียวในเวลาเดียว (ITEM-10): lot ที่ยังไม่จบของสินค้าหนึ่งมีได้แถวเดียว
    add_index :lots, :item_id, unique: true, where: "status = 'pending'", name: "index_lots_one_pending_per_item"
  end
end
