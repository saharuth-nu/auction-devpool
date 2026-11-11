# ตารางผู้ใช้ตารางเดียว แยก admin / bidder ด้วย role (requirements AUTH-04, 05, 08, 15)
# - admin มีเฉพาะ username + password (ADM-04) จึงให้ email/fullname เป็น NULL ได้
# - unique index ที่ระดับ DB ด้วย (ไม่พึ่ง validation อย่างเดียว) ค่าเก็บเป็นตัวพิมพ์เล็ก
#   SQLite ถือว่า NULL ไม่ซ้ำกัน จึงมี admin หลายคนที่ email เป็น NULL ได้
# - ฟิลด์ของสายอื่น (สถานะคุณสมบัติ, ระงับ, บังคับเปลี่ยนรหัสผ่าน) เพิ่มใน migration ของ task นั้นๆ
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :email
      t.string :fullname
      t.string :role, null: false, default: "bidder"
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :email, unique: true
  end
end
