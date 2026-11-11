require "test_helper"

# USR-01 (banner + รายการสินค้า), USR-02 (การ์ดสินค้า), USR-03 (แสดงเฉพาะสินค้าใน event ที่ยังไม่สรุปผล)
class HomeTest < ActionDispatch::IntegrationTest
  def page = Nokogiri::HTML(response.body)

  def render_listings(entries)
    Nokogiri::HTML.fragment(ApplicationController.render(partial: "home/listings", locals: { listings: entries }))
  end

  def entry(item, starts_at) = AuctionListing::Entry.new(item:, starts_at:)

  # รูปแบบเวลาเดียวกับที่หน้าเว็บแสดง (FormatHelper#display_time)
  def display_time_of(time) = ApplicationController.helpers.display_time(time)

  test "USR-01 ผู้ใช้เห็น banner คงที่ และหัวข้อสินค้าประมูล" do
    sign_in create_approved_bidder
    get root_path
    assert_response :success
    assert_equal 1, page.css("h1").size, "ต้องมี h1 เดียวต่อหน้า"
    assert_equal "ประมูลสินค้าด้วยการยื่นราคาลับ", page.at_css(".ui-page-header h1").text
    assert_equal "สินค้าประมูล", page.at_css("#listings .ui-card__title").text
  end

  def home_names
    sign_in create_approved_bidder
    get root_path
    assert_response :success
    page.css(".ui-item-card__name").map(&:text)
  end

  test "USR-03 แสดงสินค้าใน event ที่ยังไม่เริ่มและกำลังรับราคา เรียงตามเวลาเริ่ม" do
    # fixture: live (เริ่มแล้ว 10 วินาที) ก่อน upcoming (พรุ่งนี้)
    assert_equal [ "ภาพวาด", "สร้อยคอทองคำ" ], home_names
  end

  test "USR-03 ไม่แสดงสินค้าพร้อมขายที่ไม่อยู่ใน event, สินค้าใน event ที่สรุปผลแล้ว และสินค้าที่ยังไม่อนุมัติ" do
    names = home_names
    assert Item.available.exists?(name: "รถยนต์"), "fixture ต้องมีสินค้าพร้อมขายที่ไม่อยู่ใน event"
    assert_not_includes names, "รถยนต์"
    assert_not_includes names, "โคมไฟโบราณ" # event สรุปผลแล้ว
    assert_not_includes names, "นาฬิกาข้อมือ" # รออนุมัติ
  end

  test "USR-03 event ที่ถูกยกเลิกหรือสรุปผลแล้วหายจากหน้าแรก" do
    auction_events(:upcoming).cancel!
    auction_events(:live).update!(status: :settled)
    assert_empty AuctionListing.entries
    sign_in create_approved_bidder
    get root_path
    assert_equal "ยังไม่มีสินค้าเปิดประมูล", page.at_css(".ui-empty__title").text
  end

  test "USR-03 lot ที่ไม่ใช่ pending หายไป แม้ event ยังรับราคาอยู่" do
    lots(:live_painting).update!(status: :unsold)
    assert_equal [ "สร้อยคอทองคำ" ], AuctionListing.entries.map { |entry| entry.item.name }
  end

  test "USR-03 สินค้าที่เก็บถาวรแล้วไม่แสดง" do
    items(:necklace).archive!
    assert_equal [ "ภาพวาด" ], AuctionListing.entries.map { |entry| entry.item.name }
  end

  test "USR-02 การ์ดบนหน้าแรกแสดงเวลาเริ่มของ event ราคาเริ่มต้น และป้ายสถานะตามเวลา" do
    sign_in create_approved_bidder
    get root_path
    cards = page.css(".ui-item-card").to_h { |card| [ card.at_css(".ui-item-card__name").text, card ] }

    painting = cards.fetch("ภาพวาด")
    assert_equal "กำลังประมูล", painting.at_css(".ui-badge").text # event เริ่มไปแล้ว 10 วินาที
    assert_equal "5,000 บาท", painting.at_css(".ui-item-card__price").text
    assert_equal display_time_of(auction_events(:live).starts_at), painting.css(".ui-item-card__meta dd").first.text

    necklace = cards.fetch("สร้อยคอทองคำ")
    assert_equal "รอเริ่ม", necklace.at_css(".ui-badge").text
    assert_equal display_time_of(auction_events(:upcoming).starts_at), necklace.css(".ui-item-card__meta dd").first.text
  end

  test "BID-18 ราคาขั้นต่ำ (reserve) ไม่รั่วลงหน้าแรก" do
    sign_in create_approved_bidder
    get root_path
    shown = [ items(:necklace), items(:painting) ]
    assert shown.all? { |item| item.reserve_price != item.starting_price }, "fixture ต้องมี reserve ต่างจากราคาเริ่มต้น"
    shown.each do |item|
      assert_not_includes response.body, ApplicationController.helpers.baht(item.reserve_price), "reserve ของ #{item.name} รั่ว"
    end
  end

  test "USR-03 ดึงรูปครั้งเดียว ไม่ยิง query เพิ่มต่อสินค้า (ไม่มี N+1)" do
    [ items(:necklace), items(:painting) ].each do |item|
      item.images.attach(io: File.open(file_fixture("photo.png")), filename: "photo.png", content_type: "image/png")
    end
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      AuctionListing.entries.each { |entry| entry.item.images.first.blob.filename }
    end
    assert_operator queries, :<=, 6, "query มากเกินไป (#{queries}) น่าจะมี N+1"
  end

  test "QUAL-05 ผู้ใช้ที่ยังไม่ผ่านการตรวจคุณสมบัติถูกส่งไปหน้าสถานะ ไม่เห็นหน้าแรก" do
    sign_in create_bidder
    get root_path
    assert_redirected_to qualification_path
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
    assert_equal [ "300,000 บาท", "5,000 บาท" ], doc.css(".ui-item-card__price").map(&:text)
    assert_equal 2, doc.css("ul.ui-item-grid > li").size
  end

  test "USR-04 การ์ดสินค้าบนหน้าแรกคลิกไปหน้ารายละเอียดของ lot นั้น" do
    sign_in create_approved_bidder
    get root_path
    links = page.css("a.ui-item-card__link").to_h { |a| [ a.text, a["href"] ] }
    assert_equal lot_path(lots(:live_painting)), links.fetch("ภาพวาด")
    assert_equal lot_path(lots(:upcoming_necklace)), links.fetch("สร้อยคอทองคำ")
  end

  test "NFR-11 ไม่มี entry แสดงสถานะว่าง ไม่แสดงตารางเปล่า" do
    doc = render_listings([])
    assert doc.at_css(".ui-empty")
    assert_nil doc.at_css("ul.ui-item-grid")
  end

  test "AuctionListing.entries คืน Entry (contract ที่หน้าแรกพึ่งพา)" do
    assert_equal [ :item, :starts_at, :lot ], AuctionListing::Entry.members
    assert_equal [ AuctionListing::Entry ], AuctionListing.entries.map(&:class).uniq
  end
end
