# มาตรฐาน UI (Design System)

ย้ายมาจาก `mmm-admin-fe` (`docs/ui-standards.md`, `src/app/globals.css`, `src/components/ui/`)
ต้นทางเป็น Next.js + Tailwind แต่โปรเจคนี้เป็น Rails จึงแปลงเป็น CSS ธรรมดา:

- **Token**: [`app/assets/stylesheets/tokens.css`](app/assets/stylesheets/tokens.css) (CSS variables) — แก้สี/ขนาดที่นี่ที่เดียว
- **Component**: [`app/assets/stylesheets/components.css`](app/assets/stylesheets/components.css) (class `ui-*`)
- ฟอนต์โหลดใน `app/views/layouts/application.html.erb`

ถ้าสเปกในเอกสารนี้ขัดกับ CSS ให้ถือว่า CSS ถูกแก้ล่าสุดและกลับมาแก้เอกสารให้ตรงกัน

## 1. สี

**กฎข้อเดียว: ใช้ชื่อตามความหมาย ไม่ใช้ชื่อสีตรงๆ** เขียน `var(--color-primary-600)`, `var(--color-danger-700)` ไม่เขียน hex หรือชื่อสีใน view/CSS อื่น

| Token | ใช้เมื่อ |
|---|---|
| `primary-*` | สีหลักแบรนด์: ปุ่มหลัก, แท็บที่เลือก, focus ring, แถบหัวหน้า, แถวที่เลือก |
| `secondary-*` | สีรอง (ทอง) เป็นสีเน้น: เส้น/ไอคอน/แถบตกแต่ง **ไม่ใช่สีสถานะ** |
| `brand-tertiary` `#E200B0` | ข้อความ/ขอบ/ไอคอนเน้นแบรนด์ เช่น ปุ่ม outline (ใช้กับตัวหนา/ใหญ่เท่านั้น) |
| `brand-border` `#CB00A1` | ขอบช่องกรอกตอน hover/focus |
| `success-*` | สำเร็จ / ผ่าน / เสร็จสิ้น |
| `warning-*` | รอดำเนินการ / ต้องระวัง |
| `danger-*` | error / ไม่ผ่าน / ลบหรือย้อนกลับไม่ได้ |
| `info-*` | ข้อมูลทั่วไป / กำลังดำเนินการ |
| `zinc-*` | ตัวอักษร เส้น พื้นหลัง ที่ไม่มีความหมายเชิงสถานะ |

เฉด: `50` พื้นอ่อน, `100–200` ขอบ/พื้น badge, `500–600` สีหลักปุ่ม/ไอคอน, `700` ตัวอักษรบนพื้นอ่อน, `800` ตอน pressed

- **primary** `#A80689` = เฉด 600 · ตัวอักษรขาวบน 600 ได้ 6.9:1 (ผ่าน WCAG AA)
- **secondary** `#E2A727` = เฉด 600 · **ห้ามตัวอักษรขาวบน 600** (2.1:1) ใช้ `zinc-900` แทน · ตัวอักษรโทนทองบนพื้นอ่อนใช้เฉด 900 · เฉด 500/600/700 ใช้เป็นเส้น/ไอคอน/พื้นเท่านั้น
- `warning` ใกล้เคียงทองมาก (ต่าง 1.5:1) จึงห้ามใช้ `secondary` บอกสถานะ สถานะรอ/ระวังใช้ `warning` เสมอ
- ปุ่ม `ui-btn--secondary` คือปุ่มขอบเทา (รองในเชิงความสำคัญ) ไม่เกี่ยวกับสี `secondary`

**ข้อห้าม**: ห้ามใช้สีสถานะผิดความหมาย (เช่นแดงเป็นสีตกแต่ง เขียวกับสถานะ "รอ") · ห้ามบอกสถานะด้วยสีอย่างเดียว ต้องมีข้อความกำกับ (Badge มี label เสมอ)

## 2. ฟอนต์และขนาดตัวอักษร

ฟอนต์ **Noto Sans Thai** น้ำหนัก 400/500/600/700 · ปุ่มและหัวข้อใช้ semibold (600)
สเกลขยายจากปกติ **1 ขั้น** เพราะฟอนต์ไทยที่ 12–14px เล็กเกินไป ใช้ผ่าน token ห้ามฝัง `px` เอง

| token | ขนาด | ใช้กับ |
|---|---|---|
| `--text-2xs` | 12px | ป้ายเล็ก, Badge, ป้ายลอยของช่องกรอก |
| `--text-xs` | 14px | หัวคอลัมน์ตาราง, ข้อความรอง, ปุ่ม md/sm |
| `--text-sm` | 16px | เนื้อหาทั่วไป (ค่าตั้งต้นของ body), ช่องกรอก, ปุ่ม xl |
| `--text-base` | 18px | หัวข้อย่อย |
| `--text-lg` | 20px | ชื่อการ์ด/ตาราง |
| `--text-xl` | 24px | ชื่อหน้า |
| `--text-2xl` | 30px | ตัวเลขเด่น |

## 3. Component

| Component | Class | สเปก |
|---|---|---|
| **Button** | `ui-btn ui-btn--{variant}` | variant: `primary` (การกระทำหลัก **1 ปุ่มต่อส่วน**), `secondary` (ขอบเทา), `outline` (กรอบ `brand-tertiary` เช่น ดาวน์โหลด/ส่งออก), `danger` (ลบ/ย้อนกลับไม่ได้), `danger-outline`, `ghost`, `link` · ขนาด: `md` สูง 40px (ค่าเริ่มต้น), `--xl` สูง 48px (ปุ่มหลักของฟอร์ม/หน้าต่างยืนยัน), `--sm` สูง 32px · รูปทรง: pill (ค่าเริ่มต้น) หรือ `--square` มุม 8px · `--block` เต็มความกว้าง · ไอคอน 20px (xl = 24px) ห่างข้อความ 4px (xl = 8px) |
| **Badge** | `ui-badge ui-badge--{tone}` | tone: `primary` `success` `warning` `danger` `info` `neutral` `muted` (muted = ไม่ทราบ/ไม่มีข้อมูล ขอบประ) · 12px medium |
| **Alert** | `ui-alert ui-alert--{tone}` | tone: `error` `success` `warning` `info` · error/warning ใส่ `role="alert"` นอกนั้น `role="status"` — ใช้แสดง flash message |
| **Card** | `ui-card` + `__header` `__title` `__body` | พื้นขาว ขอบ 1px `zinc-200` มุม 8px เงา `xs` |
| **PageHeader** | `ui-page-header` + `__title` | ชื่อหน้า 24px semibold มีแถบสี primary นำหน้า, `actions` ชิดขวา |
| **StatCard** | `ui-stat` + `__label` `__value` | การ์ดตัวเลขสรุป มุม 16px ตัวเลข 30px bold `tabular-nums` |
| **Input / Textarea** | `ui-input` (`--sm`, `--invalid`) | สูง **48px** (sm = 40px) มุมโค้งเต็ม ขอบ **2px** `zinc-300` → hover/focus `brand-border` · invalid ขอบ `danger-500` · ข้อความ error ใต้ช่อง `ui-field__error` · Textarea มุม 16px |
| **Field** | `ui-field__label` `__hint` `__error` | ป้ายชื่อด้านบน 14px medium `zinc-600` |
| **Checkbox / Radio** | `ui-checkbox` `ui-radio` | 16px สี `primary-600` · ต้องมี `<label>` หรือ `aria-label` |
| **Table** | `ui-table-card` `ui-table` `ui-table__message` | การ์ด มุม 16px · หัวคอลัมน์สูง 44px พื้น `zinc-50` ตัวอักษร 14px semibold `zinc-500` · แถวสูง ~72px padding ข้าง 24px · คอลัมน์แรกเด่น (`zinc-900` medium) · เส้นคั่นแถว `zinc-200` · ตัวเลขใส่ class `num` (ชิดขวา, `tabular-nums`) |

ตัวอย่าง:

```erb
<div class="ui-page-header">
  <h1 class="ui-page-header__title">รายการประมูล</h1>
  <%= link_to "สร้างการประมูล", new_auction_path, class: "ui-btn ui-btn--primary" %>
</div>

<span class="ui-badge ui-badge--success">กำลังประมูล</span>
<%= button_to "ลบ", auction_path(a), method: :delete, class: "ui-btn ui-btn--danger" %>
```

### สถานะของโดเมน

ห้ามกำหนดสี badge ในแต่ละหน้า ให้ทำ helper กลางที่เดียว (เช่น `app/helpers/status_helper.rb`) แมปสถานะ → `{label, tone}` เหมือน `src/lib/status.ts` ของต้นทาง เช่น สถานะประมูล: เปิด→`success`, รอเริ่ม→`warning`, ปิด→`neutral`, ยกเลิก→`danger`

## 4. หลักการเขียนหน้า

1. ใช้ class `ui-*` ก่อนเสมอ ถ้าต้องการ component ใหม่ที่ใช้ซ้ำ ≥ 2 หน้า ให้เพิ่มใน `components.css` และเอกสารนี้ (ไม่ copy style ไปวางหน้าอื่น)
2. หนึ่งส่วนมีปุ่ม `primary` ได้ปุ่มเดียว ปุ่มอื่นเป็น `secondary`/`ghost`
3. การกระทำที่ย้อนกลับไม่ได้ (ลบ, ปิดประมูล, ยืนยันผู้ชนะ) ต้องมีขั้นยืนยันที่แสดงสิ่งที่จะเกิด ใช้ Turbo confirm หรือ modal แทนการปล่อยกดทีเดียว
4. ทุกช่องกรอกต้องมี label, ปุ่มไอคอนล้วนต้องมี `aria-label`
5. แสดงสถานะ โหลด/ว่าง/ผิดพลาด เสมอ (`ui-table__message`, `ui-alert--error`)
6. ตัวเลขในตาราง (ราคา, จำนวน bid) ชิดขวาและ `tabular-nums`

## 5. Checklist ก่อนส่งงาน

- [ ] ไม่มี hex สีหรือ `font-size` เป็น px ฝังใน view/CSS (ใช้ token)
- [ ] ใช้ `ui-btn`/`ui-badge`/`ui-alert`/`ui-input` แทน style เขียนเอง
- [ ] สถานะของโดเมนมาจาก helper กลาง
- [ ] เปิดดูหน้าจริงทั้งแบบไม่มีข้อมูล / error

## ที่ยังไม่ได้ย้ายมา

Select/DatePicker แบบ custom, Modal/ConfirmDialog, Tabs, SegmentedControl, Pagination, Switch, Spinner, EmptyState, DetailGrid — ต้นทางเป็น React component ที่มี interaction เยอะ ให้ทำเมื่อมีหน้าที่ต้องใช้จริง (ใช้ Stimulus + สเปกใน `mmm-admin-fe/docs/ui-standards.md` ส่วน 2 เป็นแบบ)
