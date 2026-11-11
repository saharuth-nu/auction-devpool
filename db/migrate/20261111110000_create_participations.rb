class CreateParticipations < ActiveRecord::Migration[8.1]
  def change
    # การ "เข้าร่วมประมูล" ของผู้ใช้ต่อ lot (USR-05..07) · ห้ามลบเมื่อมีประวัติ (NFR-19)
    # ยกเลิกการเข้าร่วม (USR-06) = ใส่ cancelled_at ไม่ลบแถว จึงเข้าร่วมใหม่ได้โดยเกิดแถวใหม่
    create_table :participations do |t|
      t.references :user, null: false, foreign_key: { on_delete: :restrict }
      t.references :lot, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :cancelled_at

      t.timestamps
    end
    # เข้าร่วมได้ครั้งเดียวต่อสินค้า (USR-06): แถวที่ยังไม่ยกเลิกของ (user, lot) มีได้แถวเดียว บังคับที่ DB ด้วย
    add_index :participations, %i[user_id lot_id], unique: true, where: "cancelled_at IS NULL",
              name: "index_participations_one_active_per_user_lot"
  end
end
