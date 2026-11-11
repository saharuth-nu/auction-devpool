# ข้อมูลตัวอย่างสำหรับ development (`db/seeds/90_development_samples.rb`)

- รันด้วย `bin/rails db:seed` · **เฉพาะ development** (`return unless Rails.env.development?`) ไม่รันใน production และ test · รันซ้ำได้ผลเดิม (หาด้วยชื่อ/username ก่อนสร้าง ไม่เปลี่ยนรหัสผ่านของบัญชีที่มีอยู่)
- ต้องรันหลัง `01_admin.rb` (ต้องมี admin) และ `02_auction_methods.rb` (ต้องมี `first_price`) — ชื่อไฟล์เรียงลำดับให้อยู่แล้ว
- ผู้ประมูล 5 คน ครบทุกสถานะคุณสมบัติ: `somchai` (ผ่าน เพดาน 5,000,000), `somying` (ผ่าน 1,000,000), `waiting` (รอ admin ตรวจ), `newbie` (รอกรอกทรัพย์สิน), `rejected1` (ไม่ผ่าน มีเหตุผล) · รหัสผ่านตัวอย่างเป็นค่า `SAMPLE_PASSWORD` ในไฟล์ (เปลี่ยนได้ด้วย ENV) ใช้เฉพาะ dev
- ห้อง 2 · สินค้า 8 (พร้อมขาย 7, รออนุมัติ 1 ไว้ลองกดอนุมัติ) · event 2 รอบที่ยังไม่เริ่ม (เวลาเริ่มอนาคตตอนสร้างครั้งแรก) รวม 5 lot · สินค้า "รถจักรยานยนต์คลาสสิก" พร้อมขายแต่ไม่อยู่ใน event ไว้ทดสอบว่าหน้าแรกไม่แสดง
- ผู้ประมูลถูกสร้างผ่าน `QualificationSubmission.submit` + `approve!/reject!(admin)` (ไม่ยัดสถานะตรงๆ) จึงมี audit log จริง
- ยังไม่มีรูปสินค้า (หน้าจอแสดง "ไม่มีรูป") · ยังไม่มี event ที่กำลังประมูล เพราะ #55 (scheduler เริ่ม event) ยังไม่เสร็จ
- test: `test/integration/development_seeds_test.rb` สลับ `Rails.env` เป็น development ชั่วคราว (`Rails.env = ActiveSupport::EnvironmentInquirer.new("development")`)
- `rails runner '...'` ที่ใส่ข้อความไทยตรงๆ ในบรรทัดคำสั่งอาจเจอ `Encoding::CompatibilityError (ASCII-8BIT and UTF-8)` ตอน interpolate — เป็นปัญหาการส่ง argument ไม่ใช่บั๊กของแอป ใช้ไฟล์ script แทน
