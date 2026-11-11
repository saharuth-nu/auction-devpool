# UI Design System

- ที่มา: ย้ายมาจาก `/Users/saharuth/Desktop/PEA/MMM/web/mmm-admin-fe` (Next.js + Tailwind v4) เมื่อ 2026-11-11
- โปรเจคนี้ไม่มี Tailwind จึงแปลงเป็น CSS ธรรมดา: `app/assets/stylesheets/tokens.css` (variables) + `components.css` (class `ui-*`)
- เอกสารมาตรฐานหลัก: `DESIGN.md` (root) — source of truth ของ "ความตั้งใจ"
- สีแบรนด์ primary `#A80689`, secondary ทอง `#E2A727` (ห้ามใช้เป็นสีสถานะ), font Noto Sans Thai, type scale ขยาย 1 ขั้น (body 16px)
- Propshaft `stylesheet_link_tag :app` รวมทุกไฟล์ใน `app/assets/stylesheets` (เรียงตามชื่อไฟล์) ตัวแปร CSS จึงใช้ข้ามไฟล์ได้
- ค่าสถานะ success/warning/danger/info ใช้ hex ของ Tailwind green/amber/red/blue ตามต้นทาง (ต้นทางแมปผ่าน var ของ Tailwind)
- ยังไม่ได้ย้าย: Select/DatePicker/Modal/Tabs/Pagination/Switch ฯลฯ (ดูท้าย DESIGN.md)

## Component กลาง (Rails helper)
- `app/helpers/ui_helper.rb` (ui_button/ui_link_button/ui_button_to/ui_badge/ui_alert/ui_flash/ui_card/ui_page_header/ui_stat_card/ui_table_card/ui_form_with), `app/helpers/status_helper.rb` (status_badge), `app/form_builders/ui_form_builder.rb` (f.ui_field/f.ui_submit)
- variant/tone/size ผิดจะ raise ArgumentError (ตั้งใจ กันพิมพ์ผิด)
- test ใน `test/helpers/`: `ActionView::TestCase` เดาโมดูล helper จากชื่อคลาสเทสต์ (UiFormBuilderTest → UiFormBuilderHelper ไม่มี) จึงต้อง `include UiHelper` เองในเทสต์ที่ไม่ได้ชื่อ UiHelperTest
- `app/form_builders/` เป็นโฟลเดอร์ใหม่ใต้ app/ Rails autoload ให้เองแต่ต้อง restart server ครั้งแรก (ไม่ควรวาง builder ใน app/helpers เพราะ `helper :all` จะพยายาม include ทุกไฟล์ *_helper.rb เท่านั้น ซึ่งโอเค แต่ชื่อ builder ไม่ลงท้าย _helper)
- สถานะประมูลใน StatusHelper เป็นค่าตั้งต้นที่เดาไว้ (scheduled/active/closed/cancelled) ต้องปรับให้ตรง enum จริง
