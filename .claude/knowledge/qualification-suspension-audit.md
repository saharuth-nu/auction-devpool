# ชั้น model ของ QUAL / SUSP / ADM-01 / audit log (tasks #33 #34–#38 #41 #71)

ส่วนหน้าจอ (controller/view) ยังไม่ทำ รอ login (#26) และ authorization กลาง (#27)

## API ที่ task อื่นใช้ได้
- **สถานะคุณสมบัติ** `user.qualification_status` (bidder เท่านั้น, admin = NULL): `awaiting_assets` → `awaiting_review` → `approved` | `rejected`
  - `user.qualified?` = bidder ที่ผ่านแล้ว (ไม่รวมเรื่องระงับ) · `user.can_submit_assets?` · `user.qualification_status_label` (ภาษาไทย)
  - allowlist ของ QUAL-05 (#35) ใช้ `qualified?` + `suspended?` ตัดสิน
- **เพดานราคา** (BID-04, #64): `user.bid_ceiling` → BigDecimal ผลรวมของรอบ approved ล่าสุด, 0 ถ้ายังไม่ผ่าน
- **ส่งทรัพย์สิน**: `QualificationSubmission.submit(user, rows)` รับ array หรือ hash แบบ `fields_for` แถวว่างถูกตัดทิ้ง คืน record (เช็ค `persisted?` / `errors`)
  - ฟอร์มส่งใหม่เติมด้วย `user.asset_rows_for_resubmission` (QUAL-15) · เหตุผลไม่ผ่าน `user.latest_rejection_reason`
- **ตรวจ**: `QualificationSubmission.review_queue` · `submission.approve!(admin)` / `submission.reject!(admin, reason)` (ลง audit log ให้เอง)
- **ระงับ** (#39, #40): `user.suspended?` · `user.suspend!(by: admin, reason:)` / `user.unsuspend!(by:, reason:)` (เหตุผลบังคับทั้งสองทาง) · scope `User.suspended` / `User.not_suspended`
  - ผลต่อ session (#39) และการประมูล (#40) ยังไม่ได้ทำในนี้
- **audit log** (ทุก task ฝั่ง admin, รวม #56 การเปิดดูราคา): `AuditLog.record!(admin:, action:, target:, change_set: {}, reason:)`
  - `action` ต้องอยู่ใน `AuditLog::ACTIONS` — งานใหม่ให้เพิ่มชื่อในลิสต์นั้น
  - key ที่เป็นค่าลับ (password, temporary_password, *_digest, *token, *secret) ถูกแทนด้วย `[ไม่บันทึก]` อัตโนมัติ
  - กรองหน้า admin: `AuditLog.filter(admin_id:, action:, target_type:, target_id:, from:, to:)`
- **รายชื่อผู้ใช้** (ADM-01): `User.directory(q:, qualification_status:, suspension: "suspended"|"active")` (เฉพาะ bidder, ยังไม่แบ่งหน้า)

## ข้อควรรู้
- ตารางประวัติ (`qualification_submissions`, `assets`, `suspension_events`, `audit_logs`) ลบไม่ได้: model raise `ReadOnlyRecord` และ FK ไม่ cascade (NFR-19) → ลบ user ที่มีประวัติไม่ได้
- `Asset#value` ตรวจจากค่าที่กรอกก่อน cast เพราะ column decimal(15,2) จะปัดทศนิยมเงียบๆ · รับค่าคั่นหลักพัน "1,500.50"
- SQLite `LIKE` ต้องใส่ `ESCAPE '\'` เองเมื่อใช้ `sanitize_sql_like`
- test helper: `create_admin`, `create_bidder`, `create_approved_bidder` ใน `test/test_helper.rb`
