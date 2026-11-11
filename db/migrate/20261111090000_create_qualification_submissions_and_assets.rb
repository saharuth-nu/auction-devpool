# ระบบตรวจสอบคุณสมบัติ (task #33 · QUAL-01, QUAL-03, QUAL-13, QUAL-16 · NFR-19)
# - users.qualification_status: สถานะ 4 ค่าของผู้ประมูล (admin เป็น NULL เพราะไม่มีขั้นตรวจ)
# - qualification_submissions: หนึ่งแถวต่อการส่งหนึ่งรอบ เก็บทุกรอบ ไม่แก้/ไม่ลบรอบเก่า
# - assets: รายการทรัพย์สินของรอบนั้น (ไม่มีไฟล์แนบ QUAL-03)
# foreign key ทุกตัวไม่ cascade (ค่าเริ่มต้นของ SQLite = ปฏิเสธการลบแถวแม่) ตาม NFR-19
class CreateQualificationSubmissionsAndAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :qualification_status, :string
    add_index :users, :qualification_status
    # ผู้ประมูลที่มีอยู่ก่อนแล้วเริ่มที่ "รอกรอกทรัพย์สิน" (QUAL-01)
    reversible do |dir|
      dir.up { execute "UPDATE users SET qualification_status = 'awaiting_assets' WHERE role = 'bidder'" }
    end

    create_table :qualification_submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :submitted_at, null: false
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :rejection_reason

      t.timestamps
    end
    add_index :qualification_submissions, [ :user_id, :submitted_at ]
    add_index :qualification_submissions, :status
    # กันส่งซ้อน: ผู้ใช้หนึ่งคนมีรอบที่ "รอตรวจ" ได้รอบเดียว แม้ยิง request พร้อมกัน
    add_index :qualification_submissions, :user_id, unique: true, where: "status = 'pending'",
              name: "index_qualification_submissions_one_pending_per_user"

    create_table :assets do |t|
      t.references :qualification_submission, null: false, foreign_key: true
      t.string :name, null: false
      # สูงสุด 1,000,000,000,000.00 บาท = 13 หลัก + ทศนิยม 2 (QUAL-03a) ห้ามใช้ float (NFR-09)
      t.decimal :value, precision: 15, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
