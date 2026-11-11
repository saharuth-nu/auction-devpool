require "test_helper"
require_relative "../support/design_lint"

# NFR-10 (ใช้ design system), NFR-11 (label/error ใต้ช่อง), NFR-13 (ย้อนกลับไม่ได้ต้องยืนยัน)
# ตรวจ view และ CSS ของทั้งโปรเจกต์ ถ้าแดง ข้อความจะบอกไฟล์ บรรทัด และวิธีแก้
class DesignLintTest < ActiveSupport::TestCase
  test "NFR-10/11/13 view และ CSS ทั้งโปรเจกต์ผ่านมาตรฐาน UI" do
    violations = DesignLint.scan
    assert_empty violations, "พบจุดที่ไม่ตรงมาตรฐาน UI (DESIGN.md):\n#{violations.join("\n")}"
  end

  # ---------- ทดสอบตัวตรวจเอง: ต้องจับของผิดได้ และไม่จับของถูก ----------

  def rules(source, file: "x.html.erb") = DesignLint.check_view(file, source).map(&:rule)

  test "NFR-10 จับสี hex ใน view และ inline style ที่ตั้งสี/ฟอนต์" do
    assert_includes rules('<div style="color: #ff0000">x</div>'), "hex-in-view"
    assert_includes rules('<svg fill="#A80689"></svg>'), "hex-in-view"
    assert_includes rules('<p style="font-size: 20px">x</p>'), "inline-style"
    assert_includes rules('<p style="background:red">x</p>'), "inline-style"
  end

  test "NFR-10 ไม่จับสิ่งที่ไม่ใช่สี: anchor, ความกว้าง, ข้อความ" do
    assert_empty rules('<a href="#fab">ข้าม</a>')
    assert_empty rules('<div style="width: 40%">x</div>')
    assert_empty rules("<%# style=\"color: #fff\" ในคอมเมนต์ไม่นับ %>\n<p>ok</p>")
  end

  test "NFR-10 จับ CSS ที่ฝัง hex และ font-size px แต่ไม่จับ token หรือคอมเมนต์" do
    bad = DesignLint.check_css("a.css", ".a { color: #A80689; font-size: 14px; } .b { font: 600 14px/20px sans-serif; }")
    assert_equal %w[hex-in-css px-font-size px-font-size], bad.map(&:rule)
    assert_empty DesignLint.check_css("a.css", "/* #fff 14px */ .a { color: var(--color-white); font-size: var(--text-xs); line-height: 18px; }")
  end

  test "NFR-10 จับปุ่มและตารางที่เขียนเอง" do
    assert_includes rules("<button class=\"btn\">บันทึก</button>"), "raw-control"
    assert_includes rules("<table class=\"data\"></table>"), "raw-table"
    assert_empty rules('<table class="ui-table"></table>')
  end

  test "NFR-11 จับช่องกรอกที่ไม่ผ่าน ui_field (จึงไม่มี label/error ใต้ช่อง)" do
    assert_includes rules('<input type="text" name="x">'), "raw-control"
    assert_includes rules("<select name=\"x\"></select>"), "raw-control"
    assert_includes rules("<%= f.text_field :name %>"), "raw-form-helper"
    assert_includes rules("<%= f.select :room_id, [] %>"), "raw-form-helper"
    assert_includes rules("<%= text_field_tag :q %>"), "raw-form-helper"
    assert_includes rules("<%= form_with model: @x do |f| %>"), "raw-form-helper"
    assert_includes rules("<%= button_to 'ออก', logout_path %>"), "raw-form-helper"
  end

  test "NFR-11 ไม่จับสิ่งที่ถูกต้อง: ui_field, ui_form_with, hidden input, select ของ Enumerable" do
    assert_empty rules("<%= ui_form_with model: @x do |f| %>\n<%= f.ui_field :name, label: 'ชื่อ' %>\n<%= f.ui_submit 'บันทึก' %>\n<% end %>")
    assert_empty rules('<input type="hidden" name="x" value="1">')
    assert_empty rules("<% @items.select(&:active?).each do |i| %><% end %>")
  end

  test "NFR-13 จับปุ่มที่ชื่อย้อนกลับไม่ได้แต่ไม่ผ่านขั้นยืนยัน" do
    assert_equal [ "no-confirm" ], rules("<%= ui_button_to \"ลบสินค้า\", item_path(i), method: :delete %>")
    assert_equal [ "no-confirm" ], rules("<%= ui_button_to 'อนุมัติ', approve_path(i) %>")
    assert_equal [ "no-confirm" ], rules("<%= ui_button_to 'ไม่ผ่าน', reject_path(i) %>")
    assert_equal [ "no-confirm" ], rules("<%= ui_button_to \"ยกเลิกการประมูล\", cancel_path(e) %>")
    assert_equal [ "no-confirm" ], rules("<%= ui_button_to \"ปิดใช้งาน\", disable_path(a) %>")
  end

  test "NFR-13 ไม่จับปุ่มที่ย้อนกลับได้ หรือที่มีขั้นยืนยันแล้ว" do
    assert_empty rules("<%= ui_button_to 'ออกจากระบบ', logout_path, method: :delete %>")
    assert_empty rules("<%= ui_button_to 'เปิดใช้งาน', enable_path(a), method: :delete %>")
    assert_empty rules("<%= ui_button_to 'เปิดประมูล', open_path(e) %>")
    assert_empty rules("<%= ui_button_to 'ยกเลิกการระงับ', unsuspend_path(u) %>")
    assert_empty rules("<%= ui_button_to 'ลบ', item_path(i), method: :delete, data: { turbo_confirm: 'ลบ?' } %>")
    assert_empty rules("<%= ui_confirm_button 'ลบสินค้า', item_path(i), title: 'ลบ?', message: 'กู้คืนไม่ได้' %>")
    assert_empty rules("<%= ui_button_to 'ปิดใช้งาน', x_path, data: { reversible: true } %>")
  end

  test "NFR-13 ปุ่มที่เขียนหลายบรรทัดก็จับได้ และรายงานเลขบรรทัดถูก" do
    source = "<p>บรรทัด 1</p>\n<%= ui_button_to \"ลบ\",\n      item_path(i),\n      method: :delete %>\n"
    violation = DesignLint.check_view("x.html.erb", source).first
    assert_equal "no-confirm", violation.rule
    assert_equal 2, violation.line
  end
end
