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
end
