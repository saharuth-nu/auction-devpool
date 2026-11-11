
## อัปเดต (finish-m1)
- PDPA (AUTH-19): `users.consented_at/terms_version`, ยินยอมเฉพาะตอน register (`require_terms`), เวอร์ชันข้อความที่ `Terms::VERSION` เปลี่ยนทุกครั้งที่แก้ `/terms`; ข้อความใน `/terms` เป็นร่าง ต้องให้เจ้าของโปรเจคตรวจ
- หน้า error (NFR-20): `config.exceptions_app = routes` → `ErrorsController` (ไม่แตะ DB); ลบ public/404,422,500.html ออกเพราะ static file ชนกับ route `/404`
  โหมดปิดปรับปรุงคือ `MAINTENANCE_MODE=1` (middleware `lib/middleware/maintenance_mode.rb`, 503, `/up` ยังปกติ)
  session หมดอายุ → flash ที่หน้า login แล้วกลับหน้าเดิมหลัง login
- Real-time (NFR-21): ห้องมี `turbo_stream_from @event`; `AuctionEvent` broadcast refresh เมื่อสถานะเปลี่ยน; Stimulus `connection-status` แสดงแบนเนอร์เมื่อหลุด
- เทสต์ที่ทดสอบหน้า error/ความลับต้องปิด `show_detailed_exceptions` ใน `env_config` ไม่งั้นได้หน้า debug
- NFR-14: `test/quality/requirements_coverage_test.rb` บังคับให้ทุก BID-* มีเทสต์อ้างถึง · ผลโหลด `docs/load-test.md`
