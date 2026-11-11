# UI Design System

- ที่มา: ย้ายมาจาก `/Users/saharuth/Desktop/PEA/MMM/web/mmm-admin-fe` (Next.js + Tailwind v4) เมื่อ 2026-11-11
- โปรเจคนี้ไม่มี Tailwind จึงแปลงเป็น CSS ธรรมดา: `app/assets/stylesheets/tokens.css` (variables) + `components.css` (class `ui-*`)
- เอกสารมาตรฐานหลัก: `DESIGN.md` (root) — source of truth ของ "ความตั้งใจ"
- สีแบรนด์ primary `#A80689`, secondary ทอง `#E2A727` (ห้ามใช้เป็นสีสถานะ), font Noto Sans Thai, type scale ขยาย 1 ขั้น (body 16px)
- Propshaft `stylesheet_link_tag :app` รวมทุกไฟล์ใน `app/assets/stylesheets` (เรียงตามชื่อไฟล์) ตัวแปร CSS จึงใช้ข้ามไฟล์ได้
- ค่าสถานะ success/warning/danger/info ใช้ hex ของ Tailwind green/amber/red/blue ตามต้นทาง (ต้นทางแมปผ่าน var ของ Tailwind)
- ยังไม่ได้ย้าย: Select/DatePicker/Modal/Tabs/Pagination/Switch ฯลฯ (ดูท้าย DESIGN.md)
