# session ฝั่งเซิร์ฟเวอร์ของผู้ที่ login (AUTH-16)
# หมดอายุตามอายุสูงสุด LIFETIME และถูกลบทิ้งเมื่อ logout / ระงับ / ปิดใช้งาน / เปลี่ยนหรือรีเซ็ตรหัสผ่าน
class Session < ApplicationRecord
  LIFETIME = 12.hours

  belongs_to :user

  def expired?
    created_at < LIFETIME.ago
  end
end
