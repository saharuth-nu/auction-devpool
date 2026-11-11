require "test_helper"

# USR-16 (หน้า การประมูลของฉัน 3 กลุ่ม), USR-17 (เมนูหลักทุกหน้า + ปุ่มเข้าห้องเมื่อ event ที่เข้าร่วมกำลังประมูล)
class MyAuctionsPageTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_approved_bidder
    @base = Time.zone.now.change(usec: 0)
    sign_in @user
  end

  def page = Nokogiri::HTML(response.body)

  def section(id) = page.at_css("section##{id}")

  def build_joined_event(hours:, user: @user, item_name: "ของ #{hours}")
    room = Room.create!(name: "ห้อง #{hours}", max_participants: 10, max_items: 5)
    starts = @base + hours.hours
    event = AuctionEvent.create!(name: "รอบ #{hours} ชม.", room:, auction_method: auction_methods(:first_price),
                                 starts_at: starts, ends_at: starts + 1.hour)
    lot = Lot.create!(auction_event: event, item: Item.create!(name: item_name, starting_price: 100, reserve_price: 100, status: :available))
    Participation.create!(user:, lot:)
    [ event, lot ]
  end

  # เลื่อนเวลาไป at แล้ว login ใหม่ (session เดิมหมดอายุเมื่อเลื่อนเกิน 1 วัน AUTH-16)
  def view_at(time, as: @user)
    travel_to(time) do
      sign_in as
      get my_auctions_path
      yield
    end
  end

  def buttons(scope) = scope.css("button").map(&:text)

  def room_links(scope, event) = scope.css("a[href='#{auction_event_room_path(event)}']")

  # ---------- USR-16: 3 กลุ่ม ----------

  test "USR-16 แสดง 3 กลุ่ม พร้อมจำนวนในแต่ละกลุ่ม" do
    build_joined_event(hours: 1)
    build_joined_event(hours: 2)
    build_joined_event(hours: 3)
    view_at(@base + 2.hours + 5.seconds) do
      assert_response :success
      assert_equal "การประมูลของฉัน", page.at_css("h1").text
      assert_equal [ "ยังไม่เริ่ม 1", "กำลังประมูล 1", "จบแล้ว 1" ], %w[upcoming live finished].map { |id| section(id).at_css("h2").text.squish }
      assert_includes section("upcoming").text, "รอบ 3 ชม."
      assert_includes section("live").text, "รอบ 2 ชม."
      assert_includes section("finished").text, "รอบ 1 ชม."
    end
  end

  test "NFR-11 กลุ่มที่ไม่มีรายการแสดง ไม่มีรายการ" do
    build_joined_event(hours: 3)
    get my_auctions_path
    assert_includes section("live").text, "ไม่มีรายการ"
    assert_includes section("finished").text, "ไม่มีรายการ"
  end

  test "NFR-11 ยังไม่เคยเข้าร่วมอะไรแสดงสถานะว่างพร้อมลิงก์ไปหน้าแรก" do
    get my_auctions_path
    assert_equal "คุณยังไม่ได้เข้าร่วมการประมูลใด", page.at_css(".ui-empty__title").text
    assert_equal root_path, page.at_css(".ui-empty a.ui-btn")["href"]
    assert_nil page.at_css("section.ui-my-section")
  end

  test "การเข้าร่วมของผู้ใช้อื่นไม่ปนมา" do
    build_joined_event(hours: 3, user: create_approved_bidder, item_name: "ของคนอื่น")
    build_joined_event(hours: 4, item_name: "ของฉัน")
    get my_auctions_path
    assert_includes page.text, "ของฉัน"
    assert_not_includes page.text, "ของคนอื่น"
  end

  # ---------- กลุ่ม ยังไม่เริ่ม ----------

  test "USR-16 ยังไม่เริ่ม: ห้อง เวลา นับถอยหลังถึงเวลาเริ่ม และสินค้าที่เข้าร่วม" do
    event, lot = build_joined_event(hours: 3)
    get my_auctions_path
    card = section("upcoming")
    dd = ->(label) { card.css("dt").find { |dt| dt.text == label }.next_element }
    assert_equal "ห้อง 3", dd.call("ห้อง").text
    assert_equal ApplicationController.helpers.display_time(event.starts_at), dd.call("เวลาประมูล").text
    countdown = dd.call("เริ่มในอีก").at_css("span[data-controller=countdown]")
    assert_in_delta 3 * 3600, countdown["data-countdown-remaining-value"].to_f, 5
    assert_match(/\A0[2-3]:\d\d:\d\d\z/, countdown.text)
    assert_equal lot_path(lot), card.at_css(".ui-my-lots a")["href"]
  end

  test "USR-06 ยังไม่เริ่ม: ยกเลิกการเข้าร่วมผ่านหน้าต่างยืนยัน แล้วกลับมาหน้านี้" do
    _event, lot = build_joined_event(hours: 3)
    get my_auctions_path
    dialog = section("upcoming").at_css("dialog.ui-dialog")
    assert dialog, "ต้องมีหน้าต่างยืนยันก่อนยกเลิก (NFR-13)"
    form = dialog.at_css("form")
    assert_equal lot_participation_path(lot), form["action"]
    assert_equal "delete", form.at_css("input[name=_method]")["value"]

    delete lot_participation_path(lot), headers: { "HTTP_REFERER" => my_auctions_url }
    assert_redirected_to my_auctions_url
    follow_redirect!
    assert_equal "ยกเลิกการเข้าร่วมแล้ว", page.at_css(".ui-alert").text.strip
    assert_equal "คุณยังไม่ได้เข้าร่วมการประมูลใด", page.at_css(".ui-empty__title").text
  end

  # ---------- กลุ่ม กำลังประมูล / จบแล้ว ----------

  test "USR-16 กำลังประมูล: มีปุ่มเข้าห้องประมูล ไม่มีปุ่มยกเลิกและไม่มีนับถอยหลัง" do
    event, = build_joined_event(hours: 2)
    view_at(@base + 2.hours + 5.seconds) do
      live = section("live")
      assert_equal [ "เข้าห้องประมูล" ], room_links(live, event).map(&:text)
      assert_nil live.at_css("dialog")
      assert_nil live.at_css("[data-controller=countdown]")
    end
  end

  test "USR-16 จบแล้ว: ไม่มีปุ่มยกเลิก และแสดงสถานะ lot ตามผล" do
    _, sold = build_joined_event(hours: 1, item_name: "ขายได้")
    _, unsold = build_joined_event(hours: 1, item_name: "ขายไม่ได้")
    _, removed = build_joined_event(hours: 1, item_name: "ถูกนำออก")
    build_joined_event(hours: 1, item_name: "รอผล")
    sold.update_columns(status: "sold", winning_price: 1000)
    unsold.update_columns(status: "unsold")
    removed.update_columns(status: "cancelled")

    view_at(@base + 1.hour + 31.seconds) do
      finished = section("finished")
      badges = finished.css(".ui-my-lots__item").to_h { |li| [ li.at_css(".ui-my-lots__name").text.squish.split(" ").first, li.at_css(".ui-badge")&.text ] }
      assert_equal "ขายแล้ว", badges["ขายได้"]
      assert_equal "ไม่ขาย", badges["ขายไม่ได้"]
      assert_equal "ถูกยกเลิก", badges["ถูกนำออก"]
      assert_equal "รอสรุปผล", badges["รอผล"]
      assert_nil finished.at_css("dialog")
      assert_includes buttons(finished), "ดูผลการประมูล"
    end
  end

  test "สินค้าลิงก์ไปหน้ารายละเอียดได้ตราบที่ event ยังไม่สรุปผล (กติกาเดียวกับหน้าแรก)" do
    build_joined_event(hours: 1)
    view_at(@base + 1.hour + 31.seconds) do # เลยเวลารับราคาแล้วแต่ยังรอสรุปผล
      assert section("finished").at_css(".ui-my-lots a"), "ยังเปิดดูได้ จึงเป็นลิงก์"
    end
  end

  test "สินค้าใน event ที่สรุปผลแล้ว หน้ารายละเอียดเปิดไม่ได้ จึงแสดงเป็นข้อความ ไม่ใช่ลิงก์" do
    event, = build_joined_event(hours: 1)
    event.update_columns(status: "settled")
    view_at(@base + 1.hour + 31.seconds) do
      assert_nil section("finished").at_css(".ui-my-lots a")
      assert_includes section("finished").text, "ของ 1"
    end
  end

  # ---------- สิทธิ์ ----------

  test "NFR-08 ยังไม่ login ถูกส่งไปหน้า login" do
    delete logout_path
    get my_auctions_path
    assert_redirected_to login_path
  end

  test "QUAL-05 ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติถูกส่งไปหน้าสถานะ" do
    sign_in create_bidder
    get my_auctions_path
    assert_redirected_to qualification_path
  end

  test "NFR-08 admin เปิดหน้าของผู้ใช้ไม่ได้ (403)" do
    sign_in create_admin
    get my_auctions_path
    assert_response :forbidden
  end

  # ---------- USR-17: เมนูหลักทุกหน้า ----------

  test "USR-17 เมนู การประมูลของฉัน อยู่ทุกหน้าของผู้ประมูลที่ผ่านตรวจ" do
    [ root_path, lot_path(lots(:upcoming_necklace)), profile_path, my_auctions_path ].each do |path|
      get path
      assert_response :success, path
      link = page.at_css("nav.ui-header__nav a.ui-header__link")
      assert link, "#{path} ต้องมีเมนู การประมูลของฉัน"
      assert_equal "การประมูลของฉัน", link.text
      assert_equal my_auctions_path, link["href"]
    end
  end

  test "USR-17 หน้าที่เปิดอยู่ถูกทำเครื่องหมาย aria-current" do
    get my_auctions_path
    assert_equal "page", page.at_css("a.ui-header__link")["aria-current"]
    get root_path
    assert_nil page.at_css("a.ui-header__link")["aria-current"]
  end

  test "USR-17 ไม่แสดงเมนูให้ admin, ผู้ที่ยังไม่ login และผู้ที่ยังไม่ผ่านการตรวจ" do
    sign_in create_admin
    get admin_root_path
    assert_nil page.at_css("a.ui-header__link")

    delete logout_path
    get login_path
    assert_nil page.at_css("a.ui-header__link")

    sign_in create_bidder
    get qualification_path
    assert_response :success
    assert_nil page.at_css("a.ui-header__link")
  end

  # ---------- USR-17: ปุ่มเข้าห้องเมื่อ event ที่เข้าร่วมกำลังประมูล ----------

  test "USR-17 หน้าแรกมีปุ่มเข้าห้องประมูลเมื่อ event ที่เข้าร่วมกำลังเปิดรับราคา" do
    event, = build_joined_event(hours: 2)
    view_at(@base + 2.hours + 5.seconds) do
      get root_path
      assert_includes page.text, "กำลังประมูล: #{event.name}"
      assert_equal 1, room_links(page, event).size
    end
  end

  test "USR-17 หน้าแรกไม่มีปุ่มเข้าห้องเมื่อยังไม่เริ่ม หรือไม่ได้เข้าร่วม หรือปิดรับราคาแล้ว" do
    event, = build_joined_event(hours: 2)
    get root_path
    assert_empty room_links(page, event) # ยังไม่เริ่ม

    travel_to(@base + 2.hours + 5.seconds) do
      sign_in create_approved_bidder # ไม่ได้เข้าร่วม
      get root_path
      assert_empty room_links(page, event) # ไม่ได้เข้าร่วม จึงไม่มีแบนเนอร์
    end
    travel_to(@base + 2.hours + 31.seconds) do
      sign_in @user
      get root_path
      assert_empty room_links(page, event) # ปิดรับราคาแล้ว
    end
  end

  test "USR-17 หน้ารายละเอียดสินค้ามีปุ่มเข้าห้องประมูลเมื่อ event ที่เข้าร่วมกำลังเปิดรับราคา" do
    event, lot = build_joined_event(hours: 2)
    travel_to(@base + 2.hours + 5.seconds) do
      sign_in @user
      get lot_path(lot)
      assert_equal 1, room_links(page, event).size
      assert_includes page.text, "ยกเลิกไม่ได้หลังเริ่มประมูล"
    end
  end
end
