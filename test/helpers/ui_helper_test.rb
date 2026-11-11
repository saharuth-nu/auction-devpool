require "test_helper"

class UiHelperTest < ActionView::TestCase
  def fragment(html) = Nokogiri::HTML.fragment(html)

  test "ui_button: ค่าเริ่มต้นเป็น primary md type=button" do
    node = fragment(ui_button("บันทึก")).at_css("button")
    assert_equal "ui-btn ui-btn--primary", node["class"]
    assert_equal "button", node["type"]
    assert_equal "บันทึก", node.text
  end

  test "ui_button: variant/size/shape/block และ class เสริม" do
    node = fragment(ui_button("ลบ", variant: :danger_outline, size: :xl, shape: :square, block: true, class: "mt-2")).at_css("button")
    classes = node["class"].split
    %w[ui-btn ui-btn--danger-outline ui-btn--xl ui-btn--square ui-btn--block mt-2].each { |c| assert_includes classes, c }
  end

  test "ui_button: ไอคอนอยู่ใน span ที่ซ่อนจาก screen reader" do
    node = fragment(ui_button("ดาวน์โหลด", variant: :outline, icon_left: "<svg></svg>".html_safe)).at_css("button")
    assert_equal "true", node.at_css("span.ui-btn__icon")["aria-hidden"]
    assert node.at_css("span.ui-btn__icon svg")
  end

  test "ui_button: variant ผิดต้อง raise" do
    error = assert_raises(ArgumentError) { ui_button("x", variant: :purple) }
    assert_match(/variant/, error.message)
  end

  test "ui_link_button: เป็นลิงก์ที่หน้าตาเหมือนปุ่ม" do
    node = fragment(ui_link_button("สร้าง", "/auctions/new", size: :sm)).at_css("a")
    assert_equal "/auctions/new", node["href"]
    assert_includes node["class"].split, "ui-btn--sm"
  end

  test "ui_button_to: สร้างฟอร์มพร้อมปุ่มและ method" do
    html = ui_button_to("ลบ", "/auctions/1", method: :delete, variant: :danger, data: { turbo_confirm: "แน่ใจไหม?" })
    doc = fragment(html)
    assert_equal "/auctions/1", doc.at_css("form")["action"]
    assert_equal "delete", doc.at_css("input[name=_method]")["value"]
    button = doc.at_css("button")
    assert_includes button["class"].split, "ui-btn--danger"
    assert_equal "แน่ใจไหม?", button["data-turbo-confirm"]
  end

  test "ui_badge: tone และ block" do
    assert_includes ui_badge("ผ่าน", tone: :success), "ui-badge--success"
    assert_includes ui_badge(tone: :muted) { "ไม่ทราบ" }, "ไม่ทราบ"
    assert_raises(ArgumentError) { ui_badge("x", tone: :green) }
  end

  test "ui_alert: role ตาม tone" do
    assert_equal "alert", fragment(ui_alert("พัง", tone: :error)).at_css("div")["role"]
    assert_equal "alert", fragment(ui_alert("ระวัง", tone: :warning)).at_css("div")["role"]
    assert_equal "status", fragment(ui_alert("สำเร็จ", tone: :success)).at_css("div")["role"]
    assert_raises(ArgumentError) { ui_alert("x", tone: :danger) }
  end

  test "ui_flash: แมป notice/alert เป็น tone และไม่แสดงอะไรเมื่อว่าง" do
    assert_equal "", ui_flash
    flash[:notice] = "บันทึกแล้ว"
    flash[:alert] = "ผิดพลาด"
    html = ui_flash
    assert_includes html, "ui-alert--success"
    assert_includes html, "ui-alert--error"
  end

  test "ui_card: หัวการ์ดและ body" do
    node = fragment(ui_card(title: "รายละเอียด", actions: "<a>แก้ไข</a>".html_safe) { "เนื้อหา" }).at_css("section.ui-card")
    assert_equal "รายละเอียด", node.at_css(".ui-card__title").text
    assert node.at_css(".ui-card__actions a")
    assert_equal "เนื้อหา", node.at_css(".ui-card__body").text
  end

  test "ui_card: ไม่มี title/actions = ไม่มี header" do
    assert_nil fragment(ui_card { "x" }).at_css("header")
  end

  test "ui_page_header: ชื่อ คำอธิบาย และปุ่มชิดขวา" do
    node = fragment(ui_page_header("รายการประมูล", description: "ทั้งหมด") { "<button>ใหม่</button>".html_safe })
    assert_equal "รายการประมูล", node.at_css("h1.ui-page-header__title").text
    assert_equal "ทั้งหมด", node.at_css(".ui-page-header__desc").text
    assert node.at_css(".ui-page-header__actions button")
  end

  test "ui_stat_card" do
    node = fragment(ui_stat_card("เปิดอยู่", 12, hint: "รายการ"))
    assert_equal "เปิดอยู่", node.at_css(".ui-stat__label").text
    assert_equal "12", node.at_css(".ui-stat__value").text
    assert_equal "รายการ", node.at_css(".ui-stat__hint").text
  end

  test "ui_table_card และ ui_table_message" do
    node = fragment(ui_table_card(title: "ทั้งหมด", footer: "ท้าย") { "<table class='ui-table'></table>".html_safe })
    assert_equal "ทั้งหมด", node.at_css(".ui-table-card__title").text
    assert node.at_css(".ui-table-card__scroll table.ui-table")
    assert_equal "ท้าย", node.at_css(".ui-table-card__footer").text

    row = fragment("<table>#{ui_table_message(3, 'ไม่พบข้อมูล')}</table>").at_css("td")
    assert_equal "3", row["colspan"]
    assert_includes row["class"], "ui-table__message"
  end

  # ---------- NFR-13: ขั้นยืนยันการกระทำที่ย้อนกลับไม่ได้ ----------

  def confirm_doc(**options)
    defaults = { title: "ลบสินค้านี้?", message: "ลบ “นาฬิกา” แล้วกู้คืนไม่ได้" }
    fragment(ui_confirm_button("ลบสินค้า", "/items/1", **defaults, **options))
  end

  test "NFR-13 ui_confirm_button: ปุ่มเปิดหน้าต่าง + dialog ที่บอกผลลัพธ์" do
    doc = confirm_doc
    trigger = doc.at_css("button.ui-btn--danger")
    assert_equal "ลบสินค้า", trigger.text
    assert_equal "button", trigger["type"] # กดแล้วยังไม่ส่งอะไร แค่เปิดหน้าต่าง
    assert_equal "confirm-dialog#open", trigger["data-action"]
    assert_equal "confirm-dialog", doc.at_css(".ui-confirm")["data-controller"]

    dialog = doc.at_css("dialog.ui-dialog")
    assert_equal "ลบสินค้านี้?", dialog.at_css("h2.ui-dialog__title").text
    assert_equal "ลบ “นาฬิกา” แล้วกู้คืนไม่ได้", dialog.at_css("p.ui-dialog__message").text
    assert_equal dialog.at_css("h2")["id"], dialog["aria-labelledby"]
    assert_equal dialog.at_css("p")["id"], dialog["aria-describedby"]
  end

  test "NFR-13 ui_confirm_button: ฟอร์มส่งไปที่ url ด้วย method ที่เลือก" do
    form = confirm_doc.at_css("dialog form")
    assert_equal "/items/1", form["action"]
    assert_equal "post", form["method"]
    assert_equal "delete", form.at_css("input[name=_method]")["value"]

    approve = fragment(ui_confirm_button("อนุมัติ", "/items/1/approve", method: :patch, variant: :primary,
                                         title: "อนุมัติสินค้า?", message: "แก้ราคาไม่ได้เมื่อเข้าประมูล")).at_css("form")
    assert_equal "patch", approve.at_css("input[name=_method]")["value"]
  end

  test "NFR-13 ui_confirm_button: โฟกัสเริ่มที่ยกเลิก ปุ่มยืนยันส่งฟอร์มและกันกดซ้ำ" do
    buttons = confirm_doc.css("dialog .ui-dialog__actions button")
    cancel, confirm = buttons
    assert_equal "ยกเลิก", cancel.text
    assert cancel.key?("autofocus")
    assert_equal "button", cancel["type"]
    assert_equal "confirm-dialog#close", cancel["data-action"]
    assert_equal "submit", confirm["type"]
    assert_equal "ลบสินค้า", confirm.text
    assert_includes confirm["class"].split, "ui-btn--danger"
    assert_equal "กำลังดำเนินการ...", confirm["data-turbo-submits-with"]
  end

  test "NFR-13 ui_confirm_button: ปรับสี ข้อความปุ่ม และ dialog หลายอันในหน้าเดียวไม่ใช้ id ซ้ำ" do
    doc = fragment(ui_confirm_button("ไม่ผ่าน", "/a", method: :post, variant: :primary, trigger_variant: :danger_outline,
                                     confirm_label: "ยืนยันไม่ผ่าน", cancel_label: "กลับ", title: "ไม่ผ่าน?", message: "ผู้ใช้จะเห็นเหตุผล") +
                   ui_confirm_button("ลบ", "/b", title: "ลบ?", message: "กู้คืนไม่ได้"))
    assert_includes doc.css("button.ui-btn").first["class"].split, "ui-btn--danger-outline"
    assert_equal [ "กลับ", "ยืนยันไม่ผ่าน" ], doc.css("dialog").first.css(".ui-dialog__actions button").map(&:text)
    ids = doc.css("[id]").map { |n| n["id"] }
    assert_equal ids.uniq, ids
  end

  test "NFR-13 ui_confirm_button: ไม่มี title หรือ message ที่บอกผลลัพธ์ raise (ไม่นับเป็นขั้นยืนยัน)" do
    assert_raises(ArgumentError) { ui_confirm_button("ลบ", "/x", title: "", message: "กู้คืนไม่ได้") }
    assert_raises(ArgumentError) { ui_confirm_button("ลบ", "/x", title: "ลบ?", message: nil) }
    assert_raises(ArgumentError) { ui_confirm_button("ลบ", "/x", title: "ลบ?", message: "x", method: :get) }
  end

  test "NFR-13 ui_confirm_button: ข้อความจากข้อมูลผู้ใช้ถูก escape" do
    html = ui_confirm_button("ลบ", "/x", title: "ลบ?", message: "<script>alert(1)</script>")
    assert_not_includes html, "<script>"
  end

  # ---------- NFR-11: สถานะว่างและกำลังโหลด ----------

  test "NFR-11 ui_empty_state: ชื่อ คำอธิบาย และปุ่ม" do
    node = fragment(ui_empty_state("ยังไม่มีการประมูล", description: "เลือกสินค้าที่สนใจ") { ui_link_button("ดูสินค้า", "/") }).at_css(".ui-empty")
    assert_equal "ยังไม่มีการประมูล", node.at_css(".ui-empty__title").text
    assert_equal "เลือกสินค้าที่สนใจ", node.at_css(".ui-empty__desc").text
    assert_equal "ดูสินค้า", node.at_css(".ui-empty__actions a.ui-btn").text
  end

  test "NFR-11 ui_empty_state: ไม่ใส่คำอธิบายหรือปุ่มก็ได้" do
    node = fragment(ui_empty_state("ว่าง")).at_css(".ui-empty")
    assert_nil node.at_css(".ui-empty__desc")
    assert_nil node.at_css(".ui-empty__actions")
  end

  test "NFR-11 ui_loading: role=status พร้อมข้อความ และซ่อน spinner จาก screen reader" do
    node = fragment(ui_loading).at_css(".ui-loading")
    assert_equal "status", node["role"]
    assert_equal "กำลังโหลด...", node.text.strip
    assert_equal "true", node.at_css(".ui-spinner")["aria-hidden"]
    assert_equal "กำลังส่งราคา...", fragment(ui_loading("กำลังส่งราคา...")).at_css(".ui-loading").text.strip
  end
end
