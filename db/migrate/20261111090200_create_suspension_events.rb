# ระงับ / ยกเลิกระงับบัญชีผู้ใช้ (task #38 · SUSP-01, SUSP-07, SUSP-08, SUSP-09)
# - users.suspended_at (เพิ่มใน AddAccountStateToUsers ของ #39): สถานะปัจจุบัน NULL = ไม่ถูกระงับ
# - suspension_events: ประวัติทุกครั้งที่ระงับ/ยกเลิก เพิ่มได้อย่างเดียว ไม่ลบ (SUSP-08)
class CreateSuspensionEvents < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :suspended_at

    create_table :suspension_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false # suspend | unsuspend
      t.text :reason, null: false
      t.datetime :created_at, null: false
    end
    add_index :suspension_events, [ :user_id, :created_at ]
  end
end
