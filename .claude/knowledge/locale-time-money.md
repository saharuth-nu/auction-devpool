# ภาษาไทย / เวลา / เงินบาท (issue #69, #70 · NFR-01, 02, 03, 09)

## ตั้งค่า (config/application.rb)
- `Time.zone = "Bangkok"` · `I18n.default_locale = :th` · DB เก็บเวลาเป็น UTC เสมอ (แสดงผลเป็นเวลาไทย)
- ข้อความ error ของ validation เป็นไทยแล้ว (`config/locales/th.yml`) เช่น `ต้องกรอก`, `ถูกใช้แล้ว` · test ที่เทียบข้อความ error ใช้ `of_kind?` หรือข้อความไทย ไม่ใช้ `/blank/`
- test/dev เปิด `raise_on_missing_translations` ถ้าเจอ "translation missing" คือขาด key ใน th.yml
- `:en` ยังโหลดไว้เป็นตาข่ายรองให้ gem ภายในเท่านั้น

## เวลา: ใช้ `Clock` เสมอ (`app/services/clock.rb`)
- ตัดสินเวลาที่ server เท่านั้น ห้ามเอาเวลาจาก params/เบราว์เซอร์มาตัดสิน นับถอยหลังบนหน้าจอเป็นแค่การแสดงผล
- `Clock.now` · `Clock.reached?(t)` (เท่ากันนับว่าถึง) · `Clock.passed?(t)` (เท่ากันยังไม่เลย) · `Clock.within?(a, b)` (นับทั้งต้นและปลาย) · `Clock.remaining(t)` (วินาที ไม่ติดลบ)
- ยื่นราคาทันไหม (BID-02): `Clock.within?(event.starts_at, event.starts_at + method.bidding_seconds)` → ครบ 30 วินาทีพอดียังทัน เกิน 1 มิลลิวินาทีไม่ทัน
- ใน test ใช้ `travel_to` / `freeze_time` (ใส่ `with_usec: true` ถ้าต้องทดสอบระดับมิลลิวินาที)
- อย่าเรียก `Time.now` / `Date.today` ตรงๆ ในโค้ดที่ตัดสินเวลา (rubocop `Rails/TimeZone` จับอยู่แล้ว)

## เงิน: `baht` / `baht_text` (`app/helpers/format_helper.rb`)
- `baht(1800)` → `฿1,800` (ในรายการ) · `baht_text(1800)` → `1,800 บาท` (ขั้นยืนยันก่อนยื่นราคา, BID-20)
- รับ Integer / BigDecimal / String ตัวเลข **หน่วยเป็นบาท** · ส่ง Float แล้ว raise · ถ้าเก็บเป็นสตางค์ให้หาร 100 เป็น BigDecimal ก่อนเรียก
- DB: คอลัมน์เงินใช้ `integer` หรือ `decimal` เท่านั้น `test/models/money_columns_test.rb` จะแดงถ้า migration ใหม่มี `float` หรือคอลัมน์ชื่อเกี่ยวกับเงิน (price/amount/value/fee/cost/reserve/balance/total/bid) ที่ไม่ใช่ integer/decimal

## วันที่: `thai_date` / `thai_datetime`
- `thai_date(t)` → `13 พ.ย. 2569` · `thai_datetime(t)` → `13 พ.ย. 2569 20:00 น.` (ปี พ.ศ. เขตเวลาไทย แม้ส่ง UTC มา)
- หน้า admin ดูเวลาที่ยื่น (BID-13): `thai_datetime(t, precision: :millisecond)` → `13 พ.ย. 2569 20:00:05.123 น.`
- `I18n.l(t)` ให้ปี ค.ศ. ตามกลไก Rails ข้อความที่ผู้ใช้เห็นให้ใช้ helper ข้างบน
