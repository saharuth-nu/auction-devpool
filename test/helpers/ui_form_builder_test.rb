require "test_helper"

class UiFormBuilderTest < ActionView::TestCase
  include UiHelper

  # โมเดลจำลองที่ไม่ต้องใช้ตารางในฐานข้อมูล
  class Sample
    include ActiveModel::Model
    attr_accessor :title, :description, :room_id, :enabled, :images
    validates :title, presence: true
  end

  setup do
    # ชื่อช่องภาษาไทยของโมเดลจำลอง (ช่องที่ไม่ใส่ label: ต้องมีชื่อใน locale ตาม NFR-01)
    I18n.backend.store_translations(:th, activemodel: { attributes: { "ui_form_builder_test/sample": {
      title: "ชื่อเรื่อง", room_id: "ห้องประมูล", enabled: "เปิดใช้งาน", images: "รูปสินค้า"
    } } })
  end

  teardown { I18n.backend.reload! }

  def render_form(record)
    ui_form_with(model: record, url: "/samples", scope: :sample) do |f|
      f.ui_field(:title, hint: "ชื่อสั้นๆ") + f.ui_field(:description, as: :textarea, label: "รายละเอียด") + f.ui_submit("บันทึก")
    end
  end

  test "ช่องกรอกมี label, ui-input และ hint" do
    doc = Nokogiri::HTML.fragment(render_form(Sample.new(title: "ของเก่า")))
    assert_equal "ชื่อเรื่อง", doc.at_css("label.ui-field__label").text # ชื่อช่องมาจาก locale ไทย
    input = doc.at_css("input.ui-input")
    assert_equal "ของเก่า", input["value"]
    assert_equal "ชื่อสั้นๆ", doc.at_css(".ui-field__hint").text
    assert_equal doc.at_css(".ui-field__hint")["id"], input["aria-describedby"]
  end

  test "textarea และ label กำหนดเองได้" do
    doc = Nokogiri::HTML.fragment(render_form(Sample.new))
    assert doc.at_css("textarea.ui-input")
    assert_includes doc.css("label").map(&:text), "รายละเอียด"
  end

  test "error จาก model แสดงใต้ช่องและตั้งค่า aria" do
    record = Sample.new
    record.validate
    doc = Nokogiri::HTML.fragment(render_form(record))
    input = doc.at_css("input.ui-input")
    assert_includes input["class"].split, "ui-input--invalid"
    assert_equal "true", input["aria-invalid"]
    assert_match(/ต้องกรอก/, doc.at_css(".ui-field__error").text) # NFR-01: error เป็นภาษาไทย
    assert_nil doc.at_css(".ui-field__hint")
  end

  test "ui_submit เป็นปุ่ม primary xl type=submit" do
    button = Nokogiri::HTML.fragment(render_form(Sample.new)).at_css("button[type=submit]")
    assert_equal "บันทึก", button.text
    assert_includes button["class"].split, "ui-btn--xl"
  end

  test "ฟอร์มที่ไม่ผูกโมเดล (scope) ใช้ได้และไม่มี error" do
    html = ui_form_with(url: "/login", scope: :login) { |f| f.ui_field(:username, label: "ชื่อผู้ใช้", value: "abc") }
    doc = Nokogiri::HTML.fragment(html)
    assert_equal "login[username]", doc.at_css("input.ui-input")["name"]
    assert_equal "abc", doc.at_css("input.ui-input")["value"]
    assert_nil doc.at_css(".ui-field__error")
  end

  test "as ที่ไม่รู้จักต้อง raise" do
    assert_raises(ArgumentError) do
      ui_form_with(model: Sample.new, url: "/samples", scope: :sample) { |f| f.ui_field(:title, as: :color) }
    end
  end

  # ---------- NFR-11: label ทุกช่อง, ชนิดช่องเพิ่ม, สถานะกำลังบันทึก ----------

  def form_with_field(record = Sample.new, &block)
    Nokogiri::HTML.fragment(ui_form_with(model: record, url: "/samples", scope: :sample, &block))
  end

  test "NFR-11 select มี label, ตัวเลือก และ include_blank" do
    doc = form_with_field { |f| f.ui_field(:room_id, as: :select, choices: [ [ "ห้อง A", 1 ], [ "ห้อง B", 2 ] ], include_blank: "เลือกห้อง") }
    select = doc.at_css("select.ui-input")
    assert_equal "ห้องประมูล", doc.at_css("label.ui-field__label").text
    assert_equal select["id"], doc.at_css("label")["for"]
    assert_equal [ "เลือกห้อง", "ห้อง A", "ห้อง B" ], select.css("option").map(&:text)
  end

  test "NFR-11 select ไม่ส่ง choices ต้อง raise" do
    assert_raises(ArgumentError) { form_with_field { |f| f.ui_field(:room_id, as: :select) } }
  end

  test "NFR-11 checkbox: ป้ายชื่ออยู่ข้างช่องและคลิกข้อความติ๊กได้" do
    doc = form_with_field { |f| f.ui_field(:enabled, as: :checkbox) }
    label = doc.at_css("label.ui-check")
    checkbox = label.at_css("input[type=checkbox].ui-checkbox")
    assert_equal checkbox["id"], label["for"]
    assert_equal "เปิดใช้งาน", label.at_css(".ui-check__text").text
  end

  test "NFR-11 file รองรับหลายไฟล์และ accept (รูปสินค้า ITEM-07)" do
    doc = form_with_field { |f| f.ui_field(:images, as: :file, multiple: true, accept: "image/webp") }
    input = doc.at_css("input[type=file].ui-input")
    assert input["multiple"]
    assert_equal "image/webp", input["accept"]
    assert_equal "รูปสินค้า", doc.at_css("label.ui-field__label").text
  end

  test "NFR-11 error แสดงใต้ select และ checkbox ด้วย" do
    record = Sample.new
    record.errors.add(:room_id, :blank)
    record.errors.add(:enabled, :accepted)
    doc = form_with_field(record) do |f|
      f.ui_field(:room_id, as: :select, choices: [ [ "ห้อง A", 1 ] ]) + f.ui_field(:enabled, as: :checkbox)
    end
    assert_equal [ "ต้องกรอก", "ต้องยอมรับก่อน" ], doc.css(".ui-field__error").map(&:text)
    assert_includes doc.at_css("select")["class"].split, "ui-input--invalid"
    assert_equal "true", doc.at_css("select")["aria-invalid"]
  end

  test "NFR-01 ช่องที่ไม่มีชื่อไทยและไม่ส่ง label raise (กันชื่อช่องอังกฤษหลุดถึงผู้ใช้)" do
    error = assert_raises(ArgumentError) { form_with_field { |f| f.ui_field(:description) } }
    assert_match "ไม่มีชื่อภาษาไทย", error.message
  end

  test "NFR-01 ฟอร์มไม่ผูกโมเดลที่ไม่ส่ง label raise ด้วย" do
    assert_raises(ArgumentError) { ui_form_with(url: "/login", scope: :login) { |f| f.ui_field(:username) } }
  end

  test "NFR-11 ฟอร์มที่ไม่ผูกโมเดลส่ง error: เองได้ แสดงใต้ช่องพร้อม aria เหมือน error จากโมเดล" do
    html = ui_form_with(url: "/x", scope: :rejection) do |f|
      f.ui_field(:reason, as: :textarea, label: "เหตุผล", error: "ต้องกรอกเหตุผล", value: "abc", rows: 3, maxlength: 500)
    end
    doc = Nokogiri::HTML.fragment(html)
    textarea = doc.at_css("textarea.ui-input")
    assert_equal "ต้องกรอกเหตุผล", doc.at_css(".ui-field__error").text
    assert_equal "rejection_reason_message", doc.at_css(".ui-field__error")["id"]
    assert_equal "rejection_reason_message", textarea["aria-describedby"]
    assert_equal "true", textarea["aria-invalid"]
    assert_includes textarea["class"].split, "ui-input--invalid"
    assert_equal "500", textarea["maxlength"]
    assert_equal "เหตุผล", doc.at_css("label.ui-field__label").text
  end

  test "NFR-11 error: ที่เป็นสตริงว่างหรือ nil ไม่นับเป็น error" do
    doc = Nokogiri::HTML.fragment(ui_form_with(url: "/x", scope: :s) { |f| f.ui_field(:reason, label: "เหตุผล", error: nil) })
    assert_nil doc.at_css(".ui-field__error")
    assert_nil doc.at_css("input")["aria-invalid"]
  end

  test "NFR-11 ui_submit แสดงสถานะกำลังบันทึกระหว่างส่ง และเปลี่ยนข้อความได้" do
    button = form_with_field { |f| f.ui_submit("บันทึก") }.at_css("button[type=submit]")
    assert_equal "กำลังบันทึก...", button["data-turbo-submits-with"]

    button = form_with_field { |f| f.ui_submit("ยื่นราคา", submitting: "กำลังส่งราคา...") }.at_css("button[type=submit]")
    assert_equal "กำลังส่งราคา...", button["data-turbo-submits-with"]
  end

  test "as: :file ออกเป็นช่องเลือกไฟล์ที่มี label และรับหลายไฟล์ได้" do
    html = ui_form_with(model: Sample.new, url: "/samples", scope: :sample) do |f|
      f.ui_field(:title, as: :file, label: "รูป", multiple: true, accept: "image/png")
    end
    doc = Nokogiri::HTML.fragment(html)
    input = doc.at_css("input[type=file].ui-input")
    assert input
    assert_equal "sample[title][]", input["name"]
    assert_equal "image/png", input["accept"]
    assert_equal "รูป", doc.at_css("label.ui-field__label").text
  end
end
