require "test_helper"

# USR-02: การ์ดสินค้าแสดง รูป, ชื่อ, เวลาประมูล, ราคาเริ่มต้น
class ItemHelperTest < ActionView::TestCase
  include UiHelper
  include StatusHelper
  include FormatHelper

  setup do
    @item = items(:car) # ราคาเริ่มต้น 300,000.00
    @starts_at = Time.zone.local(2026, 11, 13, 20, 0, 0)
  end

  def card(item = @item, **options)
    Nokogiri::HTML.fragment(item_card(item, starts_at: @starts_at, **options)).at_css("article.ui-item-card")
  end

  def attach_photo(item)
    item.images.attach(io: File.open(file_fixture("photo.png")), filename: "photo.png", content_type: "image/png")
  end

  test "USR-02 การ์ดแสดงชื่อ เวลาประมูล และราคาเริ่มต้นเป็นบาท" do
    node = card
    assert_equal "รถยนต์", node.at_css(".ui-item-card__name").text
    meta = node.at_css(".ui-item-card__meta")
    assert_equal [ "เวลาประมูล", "ราคาเริ่มต้น" ], meta.css("dt").map(&:text)
    assert_equal [ "13 พ.ย. 2569 20:00 น.", "฿300,000" ], meta.css("dd").map(&:text)
  end

  test "USR-02 ราคาที่แสดงคือราคาเริ่มต้น ไม่ใช่ราคาขั้นต่ำ (reserve เป็นความลับ BID-18)" do
    node = card(items(:car))
    assert_not_includes node.text, "350,000"
    assert_not_includes node.text, "350000"
  end

  test "USR-02 ราคาเริ่มต้นมีสตางค์แสดงทศนิยม 2 ตำแหน่ง" do
    @item.starting_price = BigDecimal("1250.5")
    assert_equal "฿1,250.50", card.at_css(".ui-item-card__price").text
  end

  test "USR-02 มีรูปแสดงรูปแรกพร้อม alt เป็นชื่อสินค้า" do
    attach_photo(@item)
    image = card.at_css("img.ui-item-card__image")
    assert image, "ต้องมี <img>"
    assert_equal "รถยนต์", image["alt"]
    assert_equal "lazy", image["loading"]
    assert_nil card.at_css(".ui-item-card__image--empty")
  end

  test "NFR-11 ไม่มีรูปแสดงกรอบ ไม่มีรูป ที่อ่านออกเสียงได้" do
    node = card.at_css(".ui-item-card__image--empty")
    assert_equal "ไม่มีรูป", node.text
    assert_equal "img", node["role"]
    assert_equal "ไม่มีรูปสินค้า รถยนต์", node["aria-label"]
    assert_nil card.at_css("img")
  end

  test "NFR-03 ป้ายสถานะดูจากเวลาของเซิร์ฟเวอร์: ก่อนเริ่ม = รอเริ่ม, ถึงเวลาแล้ว = กำลังประมูล" do
    travel_to @starts_at - 1.second do
      assert_equal "รอเริ่ม", card.at_css(".ui-badge").text
    end
    travel_to @starts_at do
      badge = card.at_css(".ui-badge")
      assert_equal "กำลังประมูล", badge.text
      assert_includes badge["class"].split, "ui-badge--success"
    end
  end

  test "USR-04 ใส่ url แล้วชื่อสินค้าเป็นลิงก์ (คลิกได้ทั้งการ์ด) ไม่ใส่ก็ไม่เป็นลิงก์" do
    link = card(url: "/items/1").at_css("a.ui-item-card__link")
    assert_equal "/items/1", link["href"]
    assert_equal "รถยนต์", link.text
    assert_nil card.at_css("a")
  end

  test "ชื่อสินค้าที่มาจากผู้ใช้ถูก escape" do
    @item.name = "<script>alert(1)</script>"
    html = item_card(@item, starts_at: @starts_at)
    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
  end

  test "เวลาที่เป็น nil raise ไม่ตีความเงียบๆ" do
    assert_raises(ArgumentError) { item_card(@item, starts_at: nil) }
  end
end
