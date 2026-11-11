# Component กลางของ Design System (ดู DESIGN.md)
#
# ทุก helper สร้าง HTML ที่ใช้ class `ui-*` จาก app/assets/stylesheets/components.css
# ใช้ได้ทุก view โดยไม่ต้อง include (Rails โหลด app/helpers ให้ทุก view อัตโนมัติ)
#
# ถ้าส่ง variant/tone ที่ไม่มีในมาตรฐาน จะ raise ArgumentError ทันที (กันพิมพ์ผิดแล้วหน้าตาเพี้ยนเงียบๆ)
# ต้องการ component ใหม่ที่ใช้ซ้ำ: เพิ่ม CSS ใน components.css + helper ที่นี่ + แถวในตาราง DESIGN.md
module UiHelper
  BUTTON_VARIANTS = %i[primary secondary outline danger danger_outline ghost link].freeze
  BUTTON_SIZES = %i[sm md xl].freeze
  BUTTON_SHAPES = %i[round square].freeze
  BADGE_TONES = %i[primary success warning danger info neutral muted].freeze
  ALERT_TONES = %i[error success warning info].freeze

  # ชื่อ key ของ flash → tone ของ Alert
  FLASH_TONES = {
    "notice" => :success, "success" => :success,
    "alert" => :error, "error" => :error,
    "warning" => :warning, "info" => :info
  }.freeze

  # ---------- Button ----------

  # class ของปุ่ม ใช้เมื่อต้องทำองค์ประกอบเองแต่อยากให้หน้าตาเป็นปุ่ม
  def ui_button_class(variant: :primary, size: :md, shape: :round, block: false, extra: nil)
    ui_check!(:variant, variant, BUTTON_VARIANTS)
    ui_check!(:size, size, BUTTON_SIZES)
    ui_check!(:shape, shape, BUTTON_SHAPES)
    class_names(
      "ui-btn",
      "ui-btn--#{variant.to_s.tr('_', '-')}",
      ("ui-btn--#{size}" unless size == :md),
      ("ui-btn--square" if shape == :square),
      ("ui-btn--block" if block),
      extra
    )
  end

  # <button> ทั่วไป  ui_button("บันทึก", type: "submit", size: :xl)
  #   icon_left / icon_right = HTML ของไอคอน (SVG) ที่จะแทรกหน้า/หลังข้อความ
  def ui_button(label = nil, variant: :primary, size: :md, shape: :round, block: false,
                icon_left: nil, icon_right: nil, type: "button", **html, &content)
    classes = ui_button_class(variant:, size:, shape:, block:, extra: html.delete(:class))
    content_tag(:button, ui_button_content(label, icon_left, icon_right, &content), type:, class: classes, **html)
  end

  # ลิงก์หน้าตาเป็นปุ่ม (GET)  ui_link_button("สร้างการประมูล", new_auction_path)
  def ui_link_button(label, url, variant: :primary, size: :md, shape: :round, block: false,
                     icon_left: nil, icon_right: nil, **html, &content)
    classes = ui_button_class(variant:, size:, shape:, block:, extra: html.delete(:class))
    link_to(url, class: classes, **html) { ui_button_content(label, icon_left, icon_right, &content) }
  end

  # ปุ่มที่ส่งฟอร์ม (POST/PATCH/DELETE) ใช้กับการลบหรือการกระทำที่เปลี่ยนข้อมูล
  #   ui_button_to("ลบ", auction_path(a), method: :delete, variant: :danger,
  #                data: { turbo_confirm: "ยืนยันลบการประมูลนี้?" })
  def ui_button_to(label, url, method: :post, variant: :primary, size: :md, shape: :round, block: false,
                   icon_left: nil, icon_right: nil, **html, &content)
    classes = ui_button_class(variant:, size:, shape:, block:, extra: html.delete(:class))
    button_to(url, method:, class: classes, form_class: "ui-inline-form", **html) do
      ui_button_content(label, icon_left, icon_right, &content)
    end
  end

  # ---------- Badge / Alert ----------

  # ป้ายสถานะ  ui_badge("กำลังประมูล", tone: :success)
  # สถานะของโดเมน (ประมูล ฯลฯ) ให้ใช้ status_badge ใน StatusHelper แทน อย่ากำหนด tone เองในหน้า
  def ui_badge(label = nil, tone: :neutral, **html, &content)
    ui_check!(:tone, tone, BADGE_TONES)
    classes = class_names("ui-badge", "ui-badge--#{tone}", html.delete(:class))
    content_tag(:span, content ? capture(&content) : label, class: classes, **html)
  end

  # แถบแจ้งผล  ui_alert("บันทึกแล้ว", tone: :success)
  # error/warning ใส่ role="alert" (screen reader อ่านทันที) นอกนั้น role="status"
  def ui_alert(message = nil, tone: :info, **html, &content)
    ui_check!(:tone, tone, ALERT_TONES)
    classes = class_names("ui-alert", "ui-alert--#{tone}", html.delete(:class))
    role = %i[error warning].include?(tone) ? "alert" : "status"
    content_tag(:div, content ? capture(&content) : message, class: classes, role:, **html)
  end

  # แสดง flash ทั้งหมดของ request เป็น Alert (notice/success→เขียว, alert/error→แดง)
  # วางไว้ใน layout หรือบนหน้า:  <%= ui_flash %>
  def ui_flash
    return "".html_safe if flash.empty?

    safe_join(
      flash.map { |key, message| ui_alert(message, tone: FLASH_TONES.fetch(key.to_s, :info)) },
      "\n"
    )
  end

  # ---------- Layout ----------

  # กรอบเนื้อหา  ui_card(title: "รายละเอียด") { ... }
  #   actions: HTML ที่ชิดขวาของหัวการ์ด (เช่นปุ่ม)
  def ui_card(title: nil, actions: nil, **html, &content)
    classes = class_names("ui-card", html.delete(:class))
    content_tag(:section, class: classes, **html) do
      header = if title || actions
        content_tag(:header, class: "ui-card__header") do
          safe_join([
            content_tag(:h2, title, class: "ui-card__title"),
            (content_tag(:div, actions, class: "ui-card__actions") if actions)
          ].compact)
        end
      end
      safe_join([ header, content_tag(:div, capture(&content), class: "ui-card__body") ].compact)
    end
  end

  # หัวหน้า (ทุกหน้าควรมี)  ui_page_header("รายการประมูล") { ui_link_button("สร้าง", new_auction_path) }
  #   block = ปุ่มการกระทำหลักของหน้า (ชิดขวา)
  def ui_page_header(title, description: nil, &actions)
    content_tag(:div, class: "ui-page-header") do
      left = content_tag(:div) do
        safe_join([
          content_tag(:h1, title, class: "ui-page-header__title"),
          (content_tag(:p, description, class: "ui-page-header__desc") if description)
        ].compact)
      end
      right = (content_tag(:div, capture(&actions), class: "ui-page-header__actions") if actions)
      safe_join([ left, right ].compact)
    end
  end

  # การ์ดตัวเลขสรุป  ui_stat_card("การประมูลที่เปิดอยู่", 12)
  def ui_stat_card(label, value, hint: nil, **html)
    classes = class_names("ui-stat", html.delete(:class))
    content_tag(:div, class: classes, **html) do
      content_tag(:div) do
        safe_join([
          content_tag(:p, label, class: "ui-stat__label"),
          content_tag(:p, value, class: "ui-stat__value"),
          (content_tag(:p, hint, class: "ui-stat__hint") if hint)
        ].compact)
      end
    end
  end

  # ---------- Table ----------

  # การ์ดตาราง: ใส่ <table class="ui-table"> ใน block
  #   ui_table_card(title: "การประมูลทั้งหมด", actions: ui_link_button(...)) do
  #     <table class="ui-table"> ... </table>
  #   end
  def ui_table_card(title: nil, actions: nil, footer: nil, **html, &content)
    classes = class_names("ui-table-card", html.delete(:class))
    content_tag(:div, class: classes, **html) do
      head = if title || actions
        content_tag(:div, class: "ui-table-card__head") do
          safe_join([
            content_tag(:h2, title, class: "ui-table-card__title"),
            (content_tag(:div, actions, class: "ui-table-card__actions") if actions)
          ].compact)
        end
      end
      safe_join([
        head,
        content_tag(:div, capture(&content), class: "ui-table-card__scroll"),
        (content_tag(:div, footer, class: "ui-table-card__footer") if footer)
      ].compact)
    end
  end

  # แถวข้อความกลางตาราง ใช้กับสถานะ "ไม่พบข้อมูล" / "เกิดข้อผิดพลาด"
  def ui_table_message(colspan, message)
    content_tag(:tr) { content_tag(:td, message, colspan:, class: "ui-table__message") }
  end

  # ---------- Form ----------

  # form_with ที่ใช้ UiFormBuilder (ช่องกรอกมีสไตล์ ui-input และแสดง error ใต้ช่องอัตโนมัติ)
  #   ui_form_with(model: @auction) { |f| f.ui_field :title; f.ui_submit "บันทึก" }
  def ui_form_with(**options, &block)
    form_with(builder: UiFormBuilder, **options, &block)
  end

  private

  def ui_check!(name, value, allowed)
    return if allowed.include?(value)

    raise ArgumentError, "ui: #{name} ไม่ถูกต้อง #{value.inspect} (ใช้ได้: #{allowed.map(&:inspect).join(', ')})"
  end

  def ui_button_content(label, icon_left, icon_right, &content)
    body = content ? capture(&content) : label
    safe_join([
      (content_tag(:span, icon_left, class: "ui-btn__icon", "aria-hidden": true) if icon_left),
      body,
      (content_tag(:span, icon_right, class: "ui-btn__icon", "aria-hidden": true) if icon_right)
    ].compact)
  end
end
