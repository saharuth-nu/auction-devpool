# หน้าแรกของผู้ใช้ (issue #57 · USR-01, 02, 03)

- `HomeController#show`: admin ถูกส่งไป `admin_root_path`, ผู้ใช้เห็น banner คงที่ (`home/_banner`) + รายการสินค้า (`home/_listings`)
- การ์ดสินค้า: `item_card(item, starts_at:, url: nil)` ใน `ItemHelper` แสดง รูปแรก, ชื่อ, เวลาประมูล, **ราคาเริ่มต้น** (ไม่แสดง reserve, BID-18) และป้าย รอเริ่ม/กำลังประมูลจาก `Clock` · ใส่ `url:` เมื่อมีหน้ารายละเอียด (#58)
- **USR-03 (เสร็จแล้ว):** `AuctionListing.entries` ดึงจาก `Lot.pending` ใน `AuctionEvent.unfinished` (scheduled หรือ bidding) และ `Item.active` เรียงตามเวลาเริ่มของ event ก่อน→หลัง พร้อม preload รูป (ไม่มี N+1) · คืน `AuctionListing::Entry(item:, starts_at:)`
- กรองจากสถานะของ **event และ lot** ไม่ใช่ของสินค้า: สินค้า "พร้อมขาย" ที่ไม่อยู่ใน event, สินค้าใน event ที่ settled/cancelled, lot ที่ sold/unsold/cancelled และสินค้าที่เก็บถาวร ไม่แสดง
- ยังไม่มีแบ่งหน้า (M1 รายการสั้น) ถ้า event เยอะให้เพิ่ม `Paginated` ของ Intuch
- รูปใช้ต้นฉบับ (ไม่ใช้ variant เพราะต้องมี libvips) ถ้ารายการยาวควรย่อรูปภายหลัง
- ยังไม่มีการกันผู้ใช้ที่ยังไม่ผ่านตรวจคุณสมบัติ (QUAL-05) ที่หน้านี้: เป็น allowlist กลางของงาน #35

# หน้ารายละเอียดสินค้า (issue #58 · USR-04, 05)
- route `resources :lots, only: :show` (`/lots/:id`) · `LotsController#show` · การ์ดบนหน้าแรกลิงก์มาที่นี่ (`Entry#lot`)
- เปิดได้เฉพาะ lot ที่หน้าแรกแสดง: ใช้ `AuctionListing.lots` ชุดเดียวกัน ที่เหลือ (event settled/cancelled, lot ไม่ pending, สินค้าเก็บถาวร, id ไม่มี) เป็น 404 · ผู้ที่ยังไม่ผ่านตรวจ → หน้าสถานะ, admin → 403
- แสดง: รูปทุกภาพ (ภาพแรกเด่น, ที่เหลือ lazy), ชื่อ, รายละเอียด, ราคาเริ่มต้น, เวลาประมูล (`display_time`), ห้อง, ชื่อ event, วิธีประมูล และระยะเวลายื่นราคา (อ่านจาก `auction_method.bidding_seconds`)
- **ห้ามแสดง reserve และห้ามบอกว่ามี reserve** (BID-18) มี test กัน
- ช่วงเวลา (`LotsHelper#lot_phase`) ตัดสินด้วย `Clock`: ก่อนเริ่ม = upcoming, เริ่มแล้วจนครบเวลารับราคา (นับรวมวินาทีสุดท้าย) = open, เกินไปแม้ 1 มิลลิวินาที = closed
- **USR-05 ปุ่ม "เข้าร่วมประมูล" ยังกดไม่ได้ (disabled)** แสดงเฉพาะก่อนถึงเวลา การเข้าร่วมจริงอยู่ที่ #59 (Participation): เปลี่ยนใน `lots/_join.html.erb` เป็นฟอร์มส่งไป participation ของ lot นั้น
