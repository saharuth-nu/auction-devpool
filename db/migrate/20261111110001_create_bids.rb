# ราคาที่ผู้ใช้ยื่น (BID-01, BID-13, NFR-05, NFR-19)
# - unique (user_id, lot_id): ยื่นได้ครั้งเดียวต่อสินค้า บังคับที่ระดับ DB การยิง request ซ้ำพร้อมกันสำเร็จได้ครั้งเดียว
# - placed_at ละเอียดระดับไมโครวินาที ใช้ตัดสินราคาเท่ากัน: ผู้ยื่นก่อนชนะ (BID-07)
# - FK แบบ restrict: ลบผู้ใช้/สินค้า(lot)ที่มีราคาที่ยื่นไว้ไม่ได้ (NFR-19)
class CreateBids < ActiveRecord::Migration[8.1]
  def change
    create_table :bids do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :lot, null: false, foreign_key: { on_delete: :restrict }
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.datetime :placed_at, null: false, precision: 6

      t.timestamps
      t.check_constraint "amount > 0", name: "bids_amount_positive"
    end
    add_index :bids, %i[user_id lot_id], unique: true
    # คัดผู้ชนะ: ราคาสูงสุดของ lot ก่อน แล้วเวลายื่นเร็วสุด
    add_index :bids, %i[lot_id amount placed_at], name: "index_bids_for_settlement"
  end
end
