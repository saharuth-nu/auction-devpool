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
    textarea: :text_area,
    file: :file_field
  }.freeze

  def ui_field(method, as: :text, label: nil, hint: nil, **options)
    builder_method = FIELD_TYPES.fetch(as) do
      raise ArgumentError, "ui: as ไม่ถูกต้อง #{as.inspect} (ใช้ได้: #{FIELD_TYPES.keys.map(&:inspect).join(', ')})"
    end

    # ฟอร์มที่ไม่ผูกโมเดล (เช่น form_with scope: :login) มี object เป็น nil/false: ไม่มี error จากโมเดล
    error = object.respond_to?(:errors) ? object.errors[method].first : nil
    message_id = "#{object_name}_#{method}_message".parameterize(separator: "_")
    classes = @template.class_names("ui-input", ("ui-input--invalid" if error), options.delete(:class))
    options[:"aria-invalid"] = true if error
    options[:"aria-describedby"] = message_id if error || hint

    @template.content_tag(:div, class: "ui-field") do
      @template.safe_join([
        self.label(method, label, class: "ui-field__label"),
        public_send(builder_method, method, class: classes, **options),
        ui_field_message(message_id, error, hint)
      ].compact)
    end
  end

  # ช่องเลือก (native <select>) หน้าตาเดียวกับ ui-input
  #   f.ui_select :status, [ [ "ผ่าน", "approved" ] ], include_blank: "ทั้งหมด"
  #   ฟอร์มที่ไม่ผูกโมเดลส่ง selected: params[:status] เพื่อคงค่าที่เลือกไว้
  def ui_select(method, choices, label: nil, hint: nil, include_blank: false, selected: nil, **html)
    error = object.respond_to?(:errors) ? object.errors[method].first : nil
    message_id = "#{object_name}_#{method}_message".parameterize(separator: "_")
    html[:class] = @template.class_names("ui-input", ("ui-input--invalid" if error), html[:class])
    html[:"aria-invalid"] = true if error
    html[:"aria-describedby"] = message_id if error || hint
    select_options = { include_blank: }
    select_options[:selected] = selected unless selected.nil?

    @template.content_tag(:div, class: "ui-field") do
      @template.safe_join([
        self.label(method, label, class: "ui-field__label"),
        select(method, choices, select_options, html),
        ui_field_message(message_id, error, hint)
      ].compact)
    end
  end

  # ปุ่มบันทึกหลักของฟอร์ม (primary ขนาด xl) ปรับได้ผ่าน variant/size
  def ui_submit(text = nil, variant: :primary, size: :xl, **options)
    text ||= submit_default_value
    @template.ui_button(text, type: "submit", variant:, size:, **options)
  end

  private

  def ui_field_message(id, error, hint)
    if error
      @template.content_tag(:p, error, id:, class: "ui-field__error")
    elsif hint
      @template.content_tag(:p, hint, id:, class: "ui-field__hint")
    end
  end
end
