# User model (task #25, AUTH-04/05/06/08/15)

- `users` ตารางเดียว แยก admin/bidder ด้วย `role` (enum string) · migration `db/migrate/20261111074942_create_users.rb` มีเฉพาะ username/email/fullname/role/password_digest — ฟิลด์ของสายอื่น (สถานะคุณสมบัติ, ระงับ, must_change_password) เพิ่มใน migration ของ task นั้น
- admin มี email/fullname เป็น NULL ได้ (ADM-04) · SQLite ถือว่า NULL ไม่ซ้ำ จึงมี unique index ที่ `email` ได้โดย admin หลายคนไม่ชน
- `normalizes` ทำ username/email เป็นตัวพิมพ์เล็ก → uniqueness ไม่สนตัวพิมพ์ใหญ่เล็ก และมี unique index ที่ DB ด้วย
- **ข้อควรระวัง (บั๊กที่เจอ):** `validates :x, presence: true, ..., if: -> { x.present? }` ทำให้ `if` ครอบ presence ด้วย ค่าว่างจึงผ่าน ต้องแยก `validates :x, presence: true` ออกจากตัวที่มี `if`
- password จำกัด 72 **ไบต์** (bcrypt) ไม่ใช่ตัวอักษร: ไทย 1 ตัว = 3 ไบต์ จึงใช้ได้สูงสุด 24 ตัว
- ต้องเปิด `gem "bcrypt"` ใน Gemfile (Rails 8 template คอมเมนต์ไว้) สำหรับ has_secure_password
- `db/schema.rb` ต้อง commit (CI ใช้เตรียม DB ทดสอบ) · ActionView::TestCase/test model ไม่ใช้ fixtures ในตารางนี้
