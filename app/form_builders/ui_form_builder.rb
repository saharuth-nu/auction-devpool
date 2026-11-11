# Form builder ของ Design System ใช้ผ่าน ui_form_with (ดู UiHelper)
#
#   <%= ui_form_with(model: @auction) do |f| %>
#     <%= f.ui_field :title %>
#     <%= f.ui_field :description, as: :textarea, hint: "รายละเอียดสินค้า" %>
#     <%= f.ui_field :starting_price, as: :number, label: "ราคาเริ่มต้น (บาท)" %>
#     <%= f.ui_submit "บันทึก" %>
#   <% end %>
#
# ui_field = ป้ายชื่อด้านบน + ช่องกรอก (ui-input) + hint / ข้อความ error ใต้ช่อง
# error มาจาก model.errors อัตโนมัติ (ขอบแดง + aria-invalid)
#
# ชนิดช่อง: as: :text (ค่าเริ่มต้น) :email :password :number :url :tel :search :date :datetime_local :textarea
#          :select (ต้องส่ง choices:)  :checkbox  :file (multiple: true / accept: "image/*" ได้)
#   f.ui_field :room_id, as: :select, choices: Room.pluck(:name, :id), include_blank: "เลือกห้อง"
#   f.ui_field :enabled, as: :checkbox, label: "เปิดใช้งาน"
#   f.ui_field :images, as: :file, multiple: true, accept: "image/jpeg,image/png,image/webp"
#
# ทุกช่องมี label เสมอ (NFR-11) และต้องเป็นภาษาไทย (NFR-01): ส่ง label: หรือเพิ่มชื่อช่องใน config/locales
#   th:
#     activerecord:
#       attributes:
#         auction_event: { name: ชื่อการประมูล }
# ถ้าไม่มีทั้งสองอย่าง dev/test จะ raise เพื่อกันชื่อช่องภาษาอังกฤษหลุดไปถึงผู้ใช้
# ปุ่มบันทึก (ui_submit) ปิดตัวเองและแสดง "กำลังบันทึก..." ระหว่างส่ง กันกดซ้ำ (NFR-11 สถานะโหลด)
class UiFormBuilder < ActionView::Helpers::FormBuilder
  FIELD_TYPES = {
    text: :text_field,
    email: :email_field,
    password: :password_field,
    number: :number_field,
    url: :url_field,
    tel: :telephone_field,
    search: :search_field,
    date: :date_field,
    datetime_local: :datetime_local_field,
    textarea: :text_area
  }.freeze

  SPECIAL_TYPES = %i[select checkbox file].freeze

  def ui_field(method, as: :text, label: nil, hint: nil, choices: nil, include_blank: nil, **options)
    ui_check_field_type!(as)
    # ฟอร์มที่ไม่ผูกโมเดล (เช่น form_with scope: :login) มี object เป็น nil/false: ไม่มี error จากโมเดล
    error = object.respond_to?(:errors) ? object.errors[method].first : nil
    message_id = "#{object_name}_#{method}_message".parameterize(separator: "_")
    options[:"aria-invalid"] = true if error
    options[:"aria-describedby"] = message_id if error || hint
    text = ui_label_text(method, label)
    message = ui_field_message(message_id, error, hint)

    return ui_checkbox_field(method, text, message, options) if as == :checkbox

    classes = @template.class_names("ui-input", ("ui-input--invalid" if error), options.delete(:class))
    control =
      case as
      when :select
        raise ArgumentError, "ui: as: :select ต้องส่ง choices:" if choices.nil?

        select(method, choices, { include_blank: }.compact, class: classes, **options)
      when :file
        file_field(method, class: classes, **options)
      else
        public_send(FIELD_TYPES.fetch(as), method, class: classes, **options)
      end

    @template.content_tag(:div, class: "ui-field") do
      @template.safe_join([ self.label(method, text, class: "ui-field__label"), control, message ].compact)
    end
  end

  # ปุ่มบันทึกหลักของฟอร์ม (primary ขนาด xl) ปรับได้ผ่าน variant/size
  # submitting: ข้อความบนปุ่มระหว่างส่ง (Turbo ปิดปุ่มให้) เช่น submitting: "กำลังส่งราคา..."
  def ui_submit(text = nil, variant: :primary, size: :xl, submitting: "กำลังบันทึก...", **options)
    text ||= submit_default_value
    data = { turbo_submits_with: submitting }.merge(options.delete(:data) || {})
    @template.ui_button(text, type: "submit", variant:, size:, data:, **options)
  end

  private

  def ui_check_field_type!(as)
    return if FIELD_TYPES.key?(as) || SPECIAL_TYPES.include?(as)

    raise ArgumentError, "ui: as ไม่ถูกต้อง #{as.inspect} (ใช้ได้: #{(FIELD_TYPES.keys + SPECIAL_TYPES).map(&:inspect).join(', ')})"
  end

  # checkbox: ป้ายชื่ออยู่ข้างช่อง (คลิกที่ข้อความก็ติ๊กได้) แทนที่จะอยู่ด้านบน
  def ui_checkbox_field(method, text, message, options)
    classes = @template.class_names("ui-checkbox", options.delete(:class))
    @template.content_tag(:div, class: "ui-field") do
      @template.safe_join([
        label(method, class: "ui-check") do
          @template.safe_join([ check_box(method, class: classes, **options), @template.content_tag(:span, text, class: "ui-check__text") ])
        end,
        message
      ].compact)
    end
  end

  # ชื่อช่องภาษาไทย: label: ที่ส่งมา → ชื่อใน locale (activerecord.attributes...) → raise ใน dev/test
  def ui_label_text(method, label)
    return label if label.present?

    translated = object.class.respond_to?(:human_attribute_name) ? object.class.human_attribute_name(method, default: "") : ""
    return translated if translated.present?

    if Rails.application.config.i18n.raise_on_missing_translations
      raise ArgumentError, "ui: ช่อง #{method.inspect} ไม่มีชื่อภาษาไทย ส่ง label: \"...\" หรือเพิ่ม " \
                           "activerecord.attributes.#{object.class.try(:model_name)&.i18n_key || object_name}.#{method} ใน config/locales"
    end
    method.to_s.humanize
  end

  def ui_field_message(id, error, hint)
    if error
      @template.content_tag(:p, error, id:, class: "ui-field__error")
    elsif hint
      @template.content_tag(:p, hint, id:, class: "ui-field__hint")
    end
  end
end
