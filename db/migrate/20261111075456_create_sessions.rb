# session ฝั่งเซิร์ฟเวอร์ (AUTH-16): หมดอายุตามเวลา และ logout/ระงับ/ปิดใช้งาน/เปลี่ยนรหัส แล้วลบแถวเพื่อให้หมดผลทันที
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
