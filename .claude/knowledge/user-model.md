# User model (task #25, AUTH-04/05/06/08/15)

- `users` ตารางเดียว แยก admin/bidder ด้วย `role` (enum string) · migration `db/migrate/20261111074942_create_users.rb` มีเฉพาะ username/email/fullname/role/password_digest — ฟิลด์ของสายอื่น (สถานะคุณสมบัติ, ระงับ, must_change_password) เพิ่มใน migration ของ task นั้น
- admin มี email/fullname เป็น NULL ได้ (ADM-04) · SQLite ถือว่า NULL ไม่ซ้ำ จึงมี unique index ที่ `email` ได้โดย admin หลายคนไม่ชน
- `normalizes` ทำ username/email เป็นตัวพิมพ์เล็ก → uniqueness ไม่สนตัวพิมพ์ใหญ่เล็ก และมี unique index ที่ DB ด้วย
- **ข้อควรระวัง (บั๊กที่เจอ):** `validates :x, presence: true, ..., if: -> { x.present? }` ทำให้ `if` ครอบ presence ด้วย ค่าว่างจึงผ่าน ต้องแยก `validates :x, presence: true` ออกจากตัวที่มี `if`
- password จำกัด 72 **ไบต์** (bcrypt) ไม่ใช่ตัวอักษร: ไทย 1 ตัว = 3 ไบต์ จึงใช้ได้สูงสุด 24 ตัว
- ต้องเปิด `gem "bcrypt"` ใน Gemfile (Rails 8 template คอมเมนต์ไว้) สำหรับ has_secure_password
- `db/schema.rb` ต้อง commit (CI ใช้เตรียม DB ทดสอบ) · ActionView::TestCase/test model ไม่ใช้ fixtures ในตารางนี้

# Authentication / บัญชี (สาย A: #26–#32, #39, #42)

## โครงสร้าง
- `Authentication` concern (`app/controllers/concerns/authentication.rb`) ใน `ApplicationController`: **ปฏิเสธโดยค่าเริ่มต้น** ลำดับ before_action: `require_authentication` → `require_password_change` → `authorize_role!`
  - controller ใหม่ต้องประกาศ `allow_roles :admin/:bidder` ไม่งั้น 403 · หน้าที่ไม่ต้อง login ใช้ `allow_unauthenticated_access` · หน้าที่เข้าได้แม้ถูกบังคับเปลี่ยนรหัสใช้ `allow_pending_password_change`
  - ฝั่ง admin สืบทอด `Admin::BaseController` (มี `allow_roles :admin`) · login แยก `/login` กับ `/admin/login` (`Admin::SessionsController < SessionsController`)
- session ฝั่ง server (ตาราง `sessions`) หมดอายุ 12 ชม. · ตรวจ `user.active_for_login?` **ทุก request** → ระงับ/ปิดใช้งานแล้วหมดผลทันที · เปลี่ยน/รีเซ็ตรหัส ลบ session
- `Current.user` / `current_user` ใช้ใน view และ controller
- ลบ admin ไม่ได้ (`before_destroy`) ใช้ปิดใช้งาน (`User#disable`/`enable`) · รีเซ็ตรหัส `User#reset_password(by:)` · เปลี่ยนรหัส `User#change_password`
- seed: `db/seeds.rb` โหลดทุกไฟล์ใน `db/seeds/` เรียงชื่อ (`01_admin.rb`) → **สายอื่นเพิ่ม seed เป็นไฟล์ใหม่ ไม่ต้องแก้ไฟล์เดียวกัน** · production ต้องตั้ง `ADMIN_PASSWORD`

## ข้อควรรู้ / ข้อผิดพลาดที่เจอ
- `rate_limit` ของ Rails ใช้ `Rails.cache` → test ต้องใช้ `:memory_store` (ตั้งใน `config/environments/test.rb`) และล้าง cache ในแต่ละ test (`ActionDispatch::IntegrationTest` setup ทำให้แล้ว)
- ใน test environment ข้อผิดพลาดแบบ route ไม่พบ / RecordNotFound **ตอบ 404 ไม่ raise** → ใช้ `assert_response :not_found`
- `with_routing` ใน integration test สร้าง session ใหม่ (cookie หาย) → login ภายใน block และต้องมี named route ที่ layout ใช้ (root/profile/logout/admin_root)
- `UiFormBuilder#ui_field` ใช้กับฟอร์มที่ไม่ผูกโมเดล (`form_with scope:`) ได้แล้ว (`object` เป็น false)
- brakeman เตือน `request.get?` ไม่รวม HEAD → ใช้ `request.get? || request.head?`
- รหัสชั่วคราวแสดงในหน้าตอบกลับครั้งเดียว (`Cache-Control: no-store`) ไม่เก็บใน flash/session · log กรอง `:passw` ไว้แล้ว
- `suspended_at` ถูกเพิ่มใน migration ของสาย A (สาย B #38 ไม่ต้องเพิ่มซ้ำ — ใช้คอลัมน์นี้ต่อและเพิ่มเฉพาะเหตุผล/ผู้ทำ/ประวัติ)

## ที่ยังค้างโดยตั้งใจ (รอ task อื่น)
- AUTH-03a: ปลายทางหลัง register ต้องเป็นหน้าสถานะ (#35) · NFR-08 ครึ่งหลัง (QUAL-05 allowlist) (#35)
- AUDIT: สร้าง/ปิดใช้งาน/รีเซ็ตรหัส admin ยังไม่ลง audit log (#71) — มี TODO(NFR-17) ในโค้ด
- หน้าแรกผู้ใช้ (`HomeController`) เป็นของชั่วคราว งาน #57 แทนที่ได้เลย
