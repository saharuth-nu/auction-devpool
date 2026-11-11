require "test_helper"

# NFR-10 (layout ใช้ design system), NFR-12 (responsive/มือถือ), NFR-13 (ยืนยันก่อนทำ)
# ตรวจโครงสร้างของหน้าจริง: เบราว์เซอร์จริงต้องเปิดดู /styleguide บนมือถือเพิ่ม (ดู DESIGN.md)
class DesignSystemPagesTest < ActionDispatch::IntegrationTest
  def page = Nokogiri::HTML(response.body)

  test "NFR-12 layout ประกาศภาษาไทยและ viewport สำหรับมือถือ" do
    get login_path
    assert_response :success
    assert_equal "th", page.at_css("html")["lang"]
    assert_equal "width=device-width,initial-scale=1", page.at_css("meta[name=viewport]")["content"]
  end

  test "NFR-12 layout มีลิงก์ข้ามไปเนื้อหา, เมนูหลัก และ main ให้ลิงก์นั้นชี้ถึง" do
    get login_path
    skip_link = page.at_css("a.ui-skip-link")
    assert_equal "#main", skip_link["href"]
    assert page.at_css("main#main.ui-main"), "ต้องมี <main id=main> ให้ลิงก์ข้ามไปถึง"
    assert page.at_css("header.ui-header")
  end

  test "NFR-10 หน้า login ใช้ component ของ design system ทั้งช่องกรอกและปุ่ม" do
    get login_path
    assert page.at_css(".ui-card form input.ui-input[name='login[username]']")
    assert page.at_css("form button.ui-btn[type=submit]")
    assert_empty page.css("input:not([type=hidden]):not(.ui-input)"), "ช่องกรอกทุกช่องต้องเป็น ui-input"
    assert_empty page.css("button:not(.ui-btn)"), "ปุ่มทุกปุ่มต้องเป็น ui-btn"
  end

  test "NFR-11 ช่องกรอกของหน้า login ทุกช่องมี label ที่ผูกกับช่อง" do
    get login_path
    page.css("input.ui-input").each do |input|
      assert page.at_css("label[for='#{input['id']}']"), "ช่อง #{input['name']} ไม่มี label"
    end
  end

  test "NFR-11 ส่งฟอร์มที่ผิด แสดง error ภาษาไทยใต้ช่อง" do
    post registration_path, params: { user: { username: "", fullname: "", email: "", password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    errors = page.css(".ui-field__error").map(&:text)
    assert_includes errors, "ต้องกรอก"
    assert page.at_css("input.ui-input--invalid[aria-invalid=true]")
  end

  # ---------- หน้าตัวอย่างทุก component (/styleguide เฉพาะ development/test) ----------

  test "styleguide: แสดง component ทั้งหมดโดยไม่ต้อง login" do
    get styleguide_path
    assert_response :success
    %w[.ui-btn .ui-badge .ui-alert .ui-card .ui-table-card .ui-stat .ui-empty .ui-loading .ui-dialog select.ui-input
       input[type=file].ui-input .ui-checkbox .ui-field__error].each do |selector|
      assert page.at_css(selector), "styleguide ไม่มี #{selector}"
    end
  end

  test "styleguide: เงินบาทและเวลาไทยแสดงถูก" do
    get styleguide_path
    text = page.text
    assert_includes text, "฿182,000"
    assert_includes text, "฿36,500.50"
    assert_includes text, "12 พ.ย. 2569 20:00 น." # 12 พ.ย. 13:00 UTC = 20:00 เวลาไทย
  end

  test "NFR-13 styleguide: ทุกปุ่มที่ย้อนกลับไม่ได้อยู่หลังหน้าต่างยืนยัน และส่งได้จริงเมื่อยืนยัน" do
    get styleguide_path
    dialogs = page.css("dialog.ui-dialog")
    assert_equal 2, dialogs.size
    dialogs.each do |dialog|
      assert dialog.at_css(".ui-dialog__title").text.present?
      assert dialog.at_css(".ui-dialog__message").text.present?
      assert_equal "post", dialog.at_css("form")["method"], "ฟอร์มยืนยันต้องส่งเมื่อกดยืนยันเท่านั้น"
    end

    delete styleguide_path # สิ่งที่ปุ่มยืนยันส่ง
    assert_response :success
    assert_includes page.at_css(".ui-alert").text, "ไม่ได้บันทึกอะไรจริง"
  end
end
