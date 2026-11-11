require "test_helper"

# USR-01 (banner + รายการสินค้า), USR-02 (การ์ดสินค้า), USR-03 (แสดงเฉพาะสินค้าใน event ที่ยังไม่สรุปผล)
class HomeTest < ActionDispatch::IntegrationTest
  def page = Nokogiri::HTML(response.body)

  def render_listings(entries)
    Nokogiri::HTML.fragment(ApplicationController.render(partial: "home/listings", locals: { listings: entries }))
  end

  def entry(item, starts_at) = AuctionListing::Entry.new(item:, starts_at:)

  test "USR-01 ผู้ใช้เห็น banner คงที่ และหัวข้อสินค้าประมูล" do
    sign_in create_bidder
    get root_path
    assert_response :success
    assert_equal 1, page.css("h1").size, "ต้องมี h1 เดียวต่อหน้า"
    assert_equal "ประมูลสินค้าด้วยการยื่นราคาลับ", page.at_css("section.ui-banner h1").text
    assert_equal "สินค้าประมูล", page.at_css("#listings-title").text
  end

  test "USR-03 ยังไม่มี event: ไม่แสดงสินค้าใดเลย แม้มีสินค้าพร้อมขายในระบบ" do
    assert Item.available.exists?, "fixture ต้องมีสินค้าพร้อมขาย"
    sign_in create_bidder
    get root_path
    assert_empty page.css(".ui-item-card")
    assert_equal "ยังไม่มีสินค้าเปิดประมูล", page.at_css(".ui-empty__title").text
  end

  test "NFR-08 ยังไม่ login ถูกส่งไปหน้า login" do
    get root_path
    assert_redirected_to login_path
  end

  test "admin เข้าหน้าแรกของผู้ใช้แล้วถูกส่งไปหน้า admin" do
    sign_in create_admin
    get root_path
    assert_redirected_to admin_root_path
  end

  test "USR-02 มี entry: แสดงการ์ดต่อสินค้าตามลำดับที่ส่งมา" do
    starts = Time.zone.local(2026, 11, 13, 20, 0, 0)
    doc = render_listings([ entry(items(:car), starts), entry(items(:painting), starts + 1.hour) ])
    assert_nil doc.at_css(".ui-empty")
    assert_equal [ "รถยนต์", "ภาพวาด" ], doc.css(".ui-item-card__name").map(&:text)
    assert_equal [ "฿300,000", "฿5,000" ], doc.css(".ui-item-card__price").map(&:text)
    assert_equal 2, doc.css("ul.ui-item-grid > li").size
  end

  test "NFR-11 ไม่มี entry แสดงสถานะว่าง ไม่แสดงตารางเปล่า" do
    doc = render_listings([])
    assert doc.at_css(".ui-empty")
    assert_nil doc.at_css("ul.ui-item-grid")
  end

  test "AuctionListing.entries คืน Entry (contract ที่หน้าแรกพึ่งพา)" do
    assert_equal [ :item, :starts_at ], AuctionListing::Entry.members
    assert_kind_of Array, AuctionListing.entries
  end
end
