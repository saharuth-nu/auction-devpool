require "test_helper"

class UiFormBuilderTest < ActionView::TestCase
  include UiHelper

  # โมเดลจำลองที่ไม่ต้องใช้ตารางในฐานข้อมูล
  class Sample
    include ActiveModel::Model
    attr_accessor :title, :description
    validates :title, presence: true
  end

  def render_form(record)
    ui_form_with(model: record, url: "/samples", scope: :sample) do |f|
      f.ui_field(:title, hint: "ชื่อสั้นๆ") + f.ui_field(:description, as: :textarea, label: "รายละเอียด") + f.ui_submit("บันทึก")
    end
  end

  test "ช่องกรอกมี label, ui-input และ hint" do
    doc = Nokogiri::HTML.fragment(render_form(Sample.new(title: "ของเก่า")))
    assert_equal "Title", doc.at_css("label.ui-field__label").text
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
    assert_match(/blank/, doc.at_css(".ui-field__error").text)
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
end
