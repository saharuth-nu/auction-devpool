# หน้าแรกของผู้ใช้ (issue #57 · USR-01, 02, 03)

- `HomeController#show`: admin ถูกส่งไป `admin_root_path`, ผู้ใช้เห็น banner คงที่ (`home/_banner`) + รายการสินค้า (`home/_listings`)
- การ์ดสินค้า: `item_card(item, starts_at:, url: nil)` ใน `ItemHelper` แสดง รูปแรก, ชื่อ, เวลาประมูล, **ราคาเริ่มต้น** (ไม่แสดง reserve, BID-18) และป้าย รอเริ่ม/กำลังประมูลจาก `Clock` · ใส่ `url:` เมื่อมีหน้ารายละเอียด (#58)
- **USR-03 (เสร็จแล้ว):** `AuctionListing.entries` ดึงจาก `Lot.pending` ใน `AuctionEvent.unfinished` (scheduled หรือ bidding) และ `Item.active` เรียงตามเวลาเริ่มของ event ก่อน→หลัง พร้อม preload รูป (ไม่มี N+1) · คืน `AuctionListing::Entry(item:, starts_at:)`
- กรองจากสถานะของ **event และ lot** ไม่ใช่ของสินค้า: สินค้า "พร้อมขาย" ที่ไม่อยู่ใน event, สินค้าใน event ที่ settled/cancelled, lot ที่ sold/unsold/cancelled และสินค้าที่เก็บถาวร ไม่แสดง
- ยังไม่มีแบ่งหน้า (M1 รายการสั้น) ถ้า event เยอะให้เพิ่ม `Paginated` ของ Intuch
- รูปใช้ต้นฉบับ (ไม่ใช้ variant เพราะต้องมี libvips) ถ้ารายการยาวควรย่อรูปภายหลัง
- ยังไม่มีการกันผู้ใช้ที่ยังไม่ผ่านตรวจคุณสมบัติ (QUAL-05) ที่หน้านี้: เป็น allowlist กลางของงาน #35
