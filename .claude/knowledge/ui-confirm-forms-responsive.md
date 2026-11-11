# Design system: ขั้นยืนยัน, ฟอร์ม, responsive (issue #74 · NFR-10, 11, 12, 13)

## ขั้นยืนยัน (NFR-13)
- `ui_confirm_button(label, url, title:, message:, method: :delete, variant: :danger)` เปิด `<dialog>` ที่บอกผลลัพธ์ ต้องกดยืนยันอีกครั้ง โฟกัสเริ่มที่ "ยกเลิก" · ต้องมี title และ message ไม่งั้น raise
- Stimulus: `app/javascript/controllers/confirm_dialog_controller.js` (เปิด/ปิด/คลิกพื้นหลัง) **ยังไม่เคยลองในเบราว์เซอร์จริง** (เครื่องที่พัฒนารัน Chrome ไม่ได้) เปิด `/styleguide` แล้วกดปุ่ม "ลบสินค้า" ตรวจก่อนใช้จริง
- ปุ่มที่ส่งฟอร์มทันที (`ui_button_to`) ใช้กับสิ่งที่ย้อนกลับได้ เช่น ออกจากระบบ, เปิดใช้งานกลับ
- ขั้นยืนยันเป็นแค่ UX: ฝั่ง server ยังต้องตรวจสิทธิ์และสถานะเองทุกครั้ง

## ฟอร์ม (NFR-11, NFR-01)
- `f.ui_field` ครบ: text/email/password/number/url/tel/search/date/datetime_local/textarea/select/checkbox/file · ทุกช่องต้องมีชื่อไทย: ส่ง `label:` หรือใส่ `activerecord.attributes.<model>.<ช่อง>` ใน locale (ไม่งั้น raise ใน dev/test)
- `f.ui_submit` กันกดซ้ำและแสดงข้อความระหว่างส่ง (`submitting: "กำลังส่งราคา..."`)
- สถานะว่าง: ตารางใช้ `ui_table_message`, รายการอื่นใช้ `ui_empty_state` · กำลังโหลด: `ui_loading`

## ตัวตรวจอัตโนมัติ
- `test/design/design_lint_test.rb` สแกน `app/views/**/*.erb` และ `app/assets/stylesheets/*.css` (ยกเว้น tokens.css): สี hex, font-size px, `style=` ที่ตั้งสี/ฟอนต์, `<input>/<select>/<textarea>/<button>/<table>` ที่เขียนเอง, `f.text_field` ฯลฯ, `button_to` ดิบ, ปุ่มชื่อ ลบ/อนุมัติ/ไม่ผ่าน/ยกเลิก/ปิดใช้งาน/ระงับ ที่ไม่มีขั้นยืนยัน
- แดงแล้วข้อความบอกไฟล์ บรรทัด และวิธีแก้ · กฎอยู่ที่ `test/support/design_lint.rb`

## Responsive
- กฎอยู่ที่ `app/assets/stylesheets/patterns.css` (โหลดหลัง components.css) · ดูหัวข้อ 6 ของ DESIGN.md
- เปิด `/styleguide` (dev/test) ดูทุก component บนมือถือ
