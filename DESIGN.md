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
| **Pagination** | `ui-pagination` + `__info` | ชิดขวา ปุ่ม secondary sm · ข้อความ 14px `zinc-500` `tabular-nums` |
| **Form row / Filter bar** | `ui-form-row` `ui-filter-bar` | `ui-form-row` = แถวกรอกหลายช่อง (2:1) ยุบเป็นคอลัมน์เดียวบนมือถือ · `ui-filter-bar` = แถบตัวกรองเหนือตาราง ช่องละ ≥ 180px ขึ้นบรรทัดใหม่อัตโนมัติ |
| **Table** | `ui-table-card` `ui-table` `ui-table__message` | การ์ด มุม 16px · หัวคอลัมน์สูง 44px พื้น `zinc-50` ตัวอักษร 14px semibold `zinc-500` · แถวสูง ~72px padding ข้าง 24px · คอลัมน์แรกเด่น (`zinc-900` medium) · เส้นคั่นแถว `zinc-200` · ตัวเลขใส่ class `num` (ชิดขวา, `tabular-nums`) |

### วิธีใช้ใน view (component กลาง)

ทีมไม่ต้องเขียน class `ui-*` เอง ใช้ helper ได้ทุก view โดยไม่ต้อง include:

| Helper | ตัวอย่าง |
|---|---|
| `ui_button` | `ui_button("บันทึก", type: "submit", size: :xl)` |
| `ui_link_button` | `ui_link_button("สร้างการประมูล", new_auction_path)` |
| `ui_button_to` | `ui_button_to("ลบ", auction_path(a), method: :delete, variant: :danger, data: { turbo_confirm: "ยืนยันลบ?" })` |
| `ui_badge` | `ui_badge("ผ่าน", tone: :success)` |
| `status_badge` | `status_badge(:auction, auction.status)` (สถานะโดเมน ดูด้านล่าง) |
| `ui_alert` / `ui_flash` | `ui_alert("บันทึกแล้ว", tone: :success)` · `ui_flash` แสดง flash ทั้งหมด |
| `ui_card` | `ui_card(title: "รายละเอียด", actions: ui_link_button(...)) { ... }` |
| `ui_page_header` | `ui_page_header("รายการประมูล", description: "...") { ui_link_button(...) }` (block = ปุ่มชิดขวา) |
| `ui_stat_card` | `ui_stat_card("เปิดอยู่", 12, hint: "รายการ")` |
| `ui_table_card` / `ui_table_message` | ดูตัวอย่างด้านล่าง |
| `ui_confirm_button` | `ui_confirm_button("ลบสินค้า", item_path(i), title: "ลบสินค้านี้?", message: "ลบ “#{i.name}” แล้วกู้คืนไม่ได้")` — ปุ่มที่เปิดหน้าต่างยืนยันก่อนส่ง ใช้กับการกระทำที่ย้อนกลับไม่ได้ (ดูหัวข้อ 4 ข้อ 3) |
| `ui_empty_state` | `ui_empty_state("ยังไม่มีการประมูล", description: "...") { ui_link_button("ดูสินค้า", root_path) }` — สถานะว่างของรายการที่ไม่ใช่ตาราง |
| `ui_loading` | `ui_loading("กำลังโหลด...")` — placeholder ใน `<turbo-frame>` ที่โหลดทีหลัง |
| `baht` / `baht_symbol` / `display_time` | จาก `FormatHelper`: `baht(1800)` → `1,800 บาท` · `baht_symbol(1800)` → `฿1,800` · `display_time(t)` → `13/11/2026 20:00` (ปี ค.ศ. ตามที่ทีมใช้) (ดู `.claude/knowledge/locale-time-money.md`) |
| `ui_form_with` + `f.ui_field` / `f.ui_submit` | ฟอร์มพร้อม label, hint และ error ใต้ช่องอัตโนมัติ |
| `f.ui_select` | `f.ui_select :status, [["ผ่าน", "approved"]], include_blank: "ทั้งหมด", selected: params[:status]` (native select หน้าตาเดียวกับ `ui-input`) |
| `ui_pagination` | `ui_pagination(@pagination)` คู่กับ `Paginated#paginate` ใน controller (ก่อนหน้า / หน้า X จาก Y / ถัดไป คงค่าตัวกรอง) วางใน `footer:` ของ `ui_table_card` |

- ชนิดช่องของ `f.ui_field`: `as:` `:text` `:email` `:password` `:number` `:url` `:tel` `:search` `:date` `:datetime_local` `:textarea` `:select` (ส่ง `choices:`) `:checkbox` `:file` (`multiple: true`, `accept:`) · ทุกช่องมี label เสมอ: ส่ง `label:` หรือเพิ่มชื่อช่องภาษาไทยใน `config/locales` (`activerecord.attributes.<model>.<ช่อง>`) ไม่งั้น dev/test จะ raise · `f.ui_submit` ปิดตัวเองและแสดง "กำลังบันทึก..." ระหว่างส่ง (เปลี่ยนด้วย `submitting:`)
- ตัวเลือก: `variant:` (`:primary :secondary :outline :danger :danger_outline :ghost :link`), `size:` (`:sm :md :xl`), `shape:` (`:round :square`), `block: true`, `icon_left:` / `icon_right:` (HTML ของ SVG)
- ส่งค่าที่ไม่อยู่ในมาตรฐาน (เช่น `variant: :purple`) จะ **raise ArgumentError** ทันที
- ทุก helper รับ `class:` เพิ่มเติมและ attribute HTML อื่นได้ (`data:`, `id:`, `aria-*`)
- โค้ด: [`app/helpers/ui_helper.rb`](app/helpers/ui_helper.rb), [`app/helpers/status_helper.rb`](app/helpers/status_helper.rb), [`app/form_builders/ui_form_builder.rb`](app/form_builders/ui_form_builder.rb) · test ที่ `test/helpers/`

```erb
<%= ui_page_header "รายการประมูล", description: "การประมูลทั้งหมดในระบบ" do %>
  <%= ui_link_button "สร้างการประมูล", new_auction_path %>
<% end %>

<%= ui_flash %>

<%= ui_table_card title: "การประมูลทั้งหมด" do %>
  <table class="ui-table">
    <thead><tr><th>ชื่อ</th><th>สถานะ</th><th class="num">ราคาปัจจุบัน</th></tr></thead>
    <tbody>
      <% if @auctions.empty? %>
        <%= ui_table_message 3, "ยังไม่มีการประมูล" %>
      <% end %>
      <% @auctions.each do |a| %>
        <tr>
          <td><%= link_to a.title, a %></td>
          <td><%= status_badge :auction, a.status %></td>
          <td class="num"><%= number_with_delimiter(a.current_price) %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>

<%= ui_form_with model: @auction do |f| %>
  <%= f.ui_field :title %>
  <%= f.ui_field :description, as: :textarea, hint: "รายละเอียดสินค้า" %>
  <%= f.ui_field :starting_price, as: :number, label: "ราคาเริ่มต้น (บาท)" %>
  <%= f.ui_submit "บันทึก" %>
<% end %>
```

ถ้าไม่ได้ผ่าน helper (เช่น ทำ HTML เอง) ใช้ class ตามตารางด้านบนได้โดยตรง

### สถานะของโดเมน

ห้ามกำหนดสี badge ในแต่ละหน้า ให้ใช้ `status_badge(:auction, status)` จาก [`StatusHelper`](app/helpers/status_helper.rb) ซึ่งแมปสถานะ → `{label, tone}` ที่เดียว (เหมือน `src/lib/status.ts` ของต้นทาง) สถานะใหม่เพิ่มที่ `STATUSES` แล้วทุกหน้าได้สีเหมือนกัน ค่าตั้งต้นของประมูล: รอเริ่ม→`warning`, กำลังประมูล→`success`, ปิด→`neutral`, ยกเลิก→`danger` (ปรับให้ตรง enum จริงเมื่อสร้าง model) · domain ที่มีแล้ว: `:qualification` (รอกรอกทรัพย์สิน→`neutral`, รอ admin ตรวจ→`warning`, ผ่าน→`success`, ไม่ผ่าน→`danger`), `:submission`, `:suspension` (`"active"`/`"suspended"`), `:suspension_event` สถานะที่ไม่รู้จักแสดงเป็น "ไม่ทราบ" (`muted`)

## 4. หลักการเขียนหน้า

1. ใช้ helper `ui_*` ก่อนเสมอ ถ้าต้องการ component ใหม่ที่ใช้ซ้ำ ≥ 2 หน้า ให้เพิ่ม CSS ใน `components.css` + helper ใน `UiHelper` + test + แถวในเอกสารนี้ (ไม่ copy style ไปวางหน้าอื่น)
2. หนึ่งส่วนมีปุ่ม `primary` ได้ปุ่มเดียว ปุ่มอื่นเป็น `secondary`/`ghost`
3. การกระทำที่ย้อนกลับไม่ได้ (ลบ, อนุมัติ, ไม่ผ่านตรวจ, ยกเลิก event, ปิดประมูล, ยืนยันผู้ชนะ) ต้องมีขั้นยืนยันที่แสดงสิ่งที่จะเกิด ใช้ `ui_confirm_button` (หรืออย่างน้อย `data: { turbo_confirm: "..." }`) แทนการปล่อยกดทีเดียว · ปุ่มส่งฟอร์มที่ชื่อขึ้นต้นด้วยคำเหล่านี้โดยไม่มีขั้นยืนยัน test จะแดง · ถ้าย้อนกลับได้จริง (เช่น เปิดใช้งานกลับ) ใส่ `data: { reversible: true }`
4. ทุกช่องกรอกต้องมี label, ปุ่มไอคอนล้วนต้องมี `aria-label`
5. แสดงสถานะ โหลด/ว่าง/ผิดพลาด เสมอ (`ui-table__message`, `ui-alert--error`)
6. ตัวเลขในตาราง (ราคา, จำนวน bid) ชิดขวาและ `tabular-nums`

## 5. Checklist ก่อนส่งงาน

- [ ] ไม่มี hex สีหรือ `font-size` เป็น px ฝังใน view/CSS (ใช้ token)
- [ ] ใช้ `ui_button`/`ui_badge`/`ui_alert`/`f.ui_field` แทน style เขียนเอง
- [ ] สถานะของโดเมนมาจาก helper กลาง
- [ ] เปิดดูหน้าจริงทั้งแบบไม่มีข้อมูล / error
- [ ] เปิดดูบนมือถือ (DevTools → Toggle device toolbar, กว้าง ~375px) ไม่มีแถบเลื่อนซ้ายขวาทั้งหน้า ตารางเลื่อนในกรอบของมันเอง
- [ ] `bin/rails test test/design` ผ่าน (ตรวจอัตโนมัติ: ไม่มี hex/px ฝัง, ไม่เขียนปุ่ม/ช่องกรอก/ตารางเอง, การกระทำย้อนกลับไม่ได้มีขั้นยืนยัน)

## 6. Responsive และมือถือ (NFR-12)

- layout (`layouts/application.html.erb`) มี `lang="th"`, viewport, ลิงก์ข้ามไปเนื้อหา, `<main id="main">` · ใส่เมนูของแต่ละส่วนใน `<nav class="ui-header__nav">`
- จุดตัด: ≤640px มือถือ (ลด padding, `ui-dl` เรียงบรรทัดเดียว, ปุ่มใน dialog เต็มความกว้าง), ≥768px เดสก์ท็อป · กฎอยู่ที่ `app/assets/stylesheets/patterns.css`
- จอสัมผัส (`pointer: coarse`): ปุ่ม/ช่อง/checkbox พื้นที่กดอย่างน้อย 44px
- ตารางอยู่ใน `ui_table_card` ซึ่งเลื่อนแนวนอนในกรอบเอง · ลูกของ `.ui-main` หดได้ (`min-width: 0`) กันหน้าล้นจอ
- **ดูหน้าตัวอย่างทุก component:** `bin/rails server` แล้วเปิด `/styleguide` (เฉพาะ development/test) ใช้ตรวจบนมือถือหลังแก้ CSS

## ที่ยังไม่ได้ย้ายมา

Select/DatePicker แบบ custom (ตอนนี้ใช้ native: `f.ui_field ..., as: :select` หรือ `f.ui_select` สำหรับแถบตัวกรอง และ `as: :date`), Modal ทั่วไป (มีเฉพาะหน้าต่างยืนยันของ `ui_confirm_button`), Tabs, SegmentedControl, Pagination แบบมีเลขหน้า (มี `ui_pagination` แบบก่อนหน้า/ถัดไป), Switch, DetailGrid (ตอนนี้ใช้ `<dl class="ui-dl">`) — ต้นทางเป็น React component ที่มี interaction เยอะ ให้ทำเมื่อมีหน้าที่ต้องใช้จริง (ใช้ Stimulus + สเปกใน `mmm-admin-fe/docs/ui-standards.md` ส่วน 2 เป็นแบบ)
