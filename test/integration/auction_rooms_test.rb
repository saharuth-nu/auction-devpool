require "test_helper"

# USR-08 (เข้าห้องตอนถึงเวลา), USR-09 (สินค้าในห้อง + นับถอยหลัง), USR-10 (เข้าร่วมเพิ่มในห้อง) ตามเวลาของ server (NFR-03)
class AuctionRoomsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_approved_bidder
    @base = Time.zone.now.change(usec: 0)
  end

  def page = Nokogiri::HTML(response.body)

  # event ในอนาคต (เริ่มอีก hours ชั่วโมง ปิดห้อง 1 ชั่วโมงหลังเริ่ม) พร้อม lots · ตรวจโดยเลื่อนเวลาไปข้างหน้า
  def build_event(hours: 2, max_participants: 10, items: [ "ของ ก", "ของ ข" ])
    room = Room.create!(name: "ห้องทดสอบ #{SecureRandom.hex(2)}", max_participants:, max_items: 10)
    starts = @base + hours.hours
    event = AuctionEvent.create!(name: "รอบทดสอบ", room:, auction_method: auction_methods(:first_price),
                                 starts_at: starts, ends_at: starts + 1.hour)
    lots = items.map { |name| Lot.create!(auction_event: event, item: Item.create!(name:, starting_price: 1000, reserve_price: 4321, status: :available)) }
    [ event, *lots ]
  end

  # เลื่อนเวลาไป at แล้ว login ใหม่ (เลื่อนเกิน 1 วัน session เดิมหมดอายุ AUTH-16)
  def open_room_at(time, event, as: @user)
    travel_to(time) do
      sign_in as
      get auction_event_room_path(event)
      yield
    end
  end

  def lot_rows = page.css("li.ui-room-lot")

  def row_for(name) = lot_rows.find { |li| li.at_css(".ui-room-lot__name").text == name }

  # ---------- USR-08: เข้าห้องตอนถึงเวลา ----------

  test "USR-08 ก่อนถึงเวลาเริ่มเข้าห้องไม่ได้ ถูกส่งไปการประมูลของฉันพร้อมข้อความ" do
    event, = build_event
    sign_in @user
    get auction_event_room_path(event)
    assert_redirected_to my_auctions_path
    follow_redirect!
    assert_includes page.at_css(".ui-alert").text, "ห้องประมูลจะเปิดเมื่อถึงเวลาเริ่ม"
    assert_includes page.at_css(".ui-alert").text, ApplicationController.helpers.display_time(event.starts_at)
  end

  test "USR-08 ถึงเวลาเริ่มพอดีเข้าห้องได้ แม้ยังไม่ได้เข้าร่วมสินค้าใด (O-11)" do
    event, = build_event
    open_room_at(event.starts_at - 1.second, event) { assert_response :redirect }
    open_room_at(event.starts_at, event) do
      assert_response :success
      assert_equal "รอบทดสอบ", page.at_css("h1").text
    end
  end

  test "EVT-06 เข้าห้องได้จนถึงเวลาปิดห้อง (ends_at) พอดี เกินไปเข้าไม่ได้" do
    event, = build_event
    open_room_at(event.ends_at, event) { assert_response :success }
    open_room_at(event.ends_at + 1.second, event) do
      assert_redirected_to my_auctions_path
      follow_redirect!
      assert_equal "ห้องประมูลปิดแล้ว", page.at_css(".ui-alert").text.strip
    end
  end

  test "event ที่สรุปผลแล้ว พาไปการประมูลของฉันพร้อมข้อความ (ผู้ที่อยู่ในห้องตอนหมดเวลาต้องไม่เจอ 404)" do
    event, = build_event
    event.update_columns(status: "settled")
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_redirected_to my_auctions_path
      follow_redirect!
      assert_select ".ui-alert--success", /สรุปผลแล้ว/
    end
  end

  test "event ที่ยกเลิกแล้วไม่มีห้อง (404)" do
    other, = build_event(hours: 3)
    other.update_columns(status: "cancelled")
    open_room_at(other.starts_at + 5.seconds, other) { assert_response :not_found }
  end

  test "id ที่ไม่มีอยู่ได้ 404" do
    sign_in @user
    get auction_event_room_path(0)
    assert_response :not_found
  end

  # ---------- USR-09: สินค้าในห้อง + นับถอยหลัง ----------

  test "USR-09 แสดงสินค้าที่อยู่ในประมูลขณะนั้น พร้อมราคาเริ่มต้นและลิงก์ไปหน้ารายละเอียด" do
    event, lot_a, = build_event
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_equal [ "ของ ก", "ของ ข" ], lot_rows.map { |li| li.at_css(".ui-room-lot__name").text }
      row = row_for("ของ ก")
      assert_equal lot_path(lot_a), row.at_css("a.ui-room-lot__name")["href"]
      assert_equal "ราคาเริ่มต้น 1,000 บาท", row.at_css(".ui-room-lot__price").text
    end
  end

  test "USR-09 สินค้าที่ไม่ pending (ยกเลิก/เก็บถาวร) ไม่แสดงในห้อง" do
    event, lot_a, lot_b = build_event
    lot_a.update!(status: :cancelled)
    lot_b.item.archive!
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_empty lot_rows
      assert_equal "ไม่มีสินค้าในห้องนี้ตอนนี้", page.at_css(".ui-empty__title").text
    end
  end

  test "USR-09 นับถอยหลังถึงเวลาปิดรับราคา ส่งวินาทีที่เหลือจากเซิร์ฟเวอร์" do
    event, = build_event
    open_room_at(event.starts_at + 10.seconds, event) do
      countdown = page.at_css("span[data-controller=countdown]")
      assert countdown, "ต้องมีนับถอยหลัง"
      assert_in_delta 20, countdown["data-countdown-remaining-value"].to_f, 1 # ปิดรับราคาเมื่อเริ่ม + 30 วินาที
      assert_equal "ปิดรับราคาใน", page.css(".ui-dl dt").map(&:text).find { |t| t == "ปิดรับราคาใน" }
    end
  end

  test "NFR-03 เลยเวลารับราคาแต่ยังไม่ปิดห้อง: บอกว่าปิดรับราคาแล้ว ไม่มีนับถอยหลังและไม่มีปุ่มเข้าร่วม" do
    event, = build_event
    open_room_at(event.bidding_ends_at + 1.second, event) do
      assert_response :success
      assert_equal "ปิดรับราคาแล้ว กำลังสรุปผล", page.at_css(".ui-card .ui-alert").text.strip
      assert_nil page.at_css("[data-controller=countdown]")
      assert_empty page.css("button").select { |b| b.text == "เข้าร่วมประมูล" }
      assert_equal "ปิดประมูล", page.at_css(".ui-page-header .ui-badge").text
    end
  end

  test "BID-18 ห้องไม่แสดงราคาขั้นต่ำ (reserve)" do
    event, = build_event
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_not_includes response.body, ApplicationController.helpers.baht(4321)
      assert_not_includes page.text.downcase, "reserve"
      assert_not_includes page.text, "ราคาขั้นต่ำ"
    end
  end

  # ---------- USR-10: เข้าร่วมสินค้าอื่นเพิ่มในห้อง ----------

  test "USR-10 สินค้าที่ยังไม่เข้าร่วมมีปุ่มเข้าร่วม สินค้าที่เข้าร่วมแล้วแสดงเข้าร่วมแล้ว" do
    event, lot_a, = build_event
    Participation.create!(user: @user, lot: lot_a)
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_equal "เข้าร่วมแล้ว", row_for("ของ ก").at_css(".ui-badge").text
      # lot ที่เข้าร่วมแล้วไม่มีปุ่ม "เข้าร่วมประมูล" ซ้ำ (มีแต่ช่องยื่นราคาของ #65 ในช่วงเปิดรับราคา)
      assert_nil row_for("ของ ก").css("button").find { |b| b.text == "เข้าร่วมประมูล" }
      assert_equal "เข้าร่วมประมูล", row_for("ของ ข").at_css("button").text
    end
  end

  test "USR-10 กดเข้าร่วมในห้องแล้วกลับมาห้องเดิม และสินค้านั้นกลายเป็นเข้าร่วมแล้ว (O-8 หลังเริ่มแล้ว)" do
    event, _lot_a, lot_b = build_event
    travel_to(event.starts_at + 5.seconds) do
      sign_in @user
      get auction_event_room_path(event)
      form = row_for("ของ ข").at_css("form")
      assert_equal lot_participation_path(lot_b), form["action"]

      assert_difference -> { Participation.active.count }, 1 do
        post lot_participation_path(lot_b), headers: { "HTTP_REFERER" => auction_event_room_url(event) }
      end
      assert_redirected_to auction_event_room_url(event)
      follow_redirect!
      assert_equal "เข้าร่วมประมูลเรียบร้อย", page.at_css(".ui-alert").text.strip
      assert_equal "เข้าร่วมแล้ว", row_for("ของ ข").at_css(".ui-badge").text
    end
  end

  test "USR-10 ห้องเต็ม: คนใหม่เห็นเต็มแล้ว กดเข้าร่วมตรงๆ ไม่ได้ แต่คนที่อยู่ใน event แล้วเข้าร่วมเพิ่มได้" do
    event, lot_a, lot_b = build_event(max_participants: 1)
    member = create_approved_bidder
    Participation.create!(user: member, lot: lot_a)

    open_room_at(event.starts_at + 5.seconds, event) do # ผู้ใช้ใหม่ในห้องที่เต็ม
      assert row_for("ของ ข").at_css("button[disabled]"), "ต้องกดไม่ได้"
      assert_equal "เต็มแล้ว", row_for("ของ ข").at_css("button").text
      assert_no_difference -> { Participation.count } do
        post lot_participation_path(lot_b)
      end
    end
    open_room_at(event.starts_at + 5.seconds, event, as: member) do # คนเดิมเข้าร่วมสินค้าอื่นเพิ่มได้
      assert_equal "เข้าร่วมประมูล", row_for("ของ ข").at_css("button").text
      assert_not row_for("ของ ข").at_css("button")["disabled"]
    end
  end

  test "ผู้เข้าร่วมแสดงจำนวนคนต่อความจุห้อง" do
    event, lot_a, = build_event(max_participants: 5)
    Participation.create!(user: @user, lot: lot_a)
    Participation.create!(user: create_approved_bidder, lot: lot_a)
    open_room_at(event.starts_at + 5.seconds, event) do
      assert_equal "2 / 5 คน", page.css(".ui-dl dt").find { |dt| dt.text == "ผู้เข้าร่วม" }.next_element.text
    end
  end

  # ---------- ลิงก์เข้าห้อง ----------

  test "ลิงก์เข้าห้องประมูลจากการประมูลของฉันใช้ได้จริง" do
    event, lot_a, = build_event
    Participation.create!(user: @user, lot: lot_a)
    travel_to(event.starts_at + 5.seconds) do
      sign_in @user
      get my_auctions_path
      link = page.at_css("section#live a.ui-btn")
      assert_equal auction_event_room_path(event), link["href"]
      get link["href"]
      assert_response :success
    end
  end

  # ---------- สิทธิ์ ----------

  test "NFR-08 ยังไม่ login ถูกส่งไปหน้า login" do
    event, = build_event
    get auction_event_room_path(event)
    assert_redirected_to login_path
  end

  test "QUAL-05 ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติเข้าห้องไม่ได้" do
    event, = build_event
    travel_to(event.starts_at + 5.seconds) do
      sign_in create_bidder
      get auction_event_room_path(event)
      assert_redirected_to qualification_path
    end
  end

  test "NFR-08 admin เข้าห้องของผู้ใช้ไม่ได้ (403)" do
    event, = build_event
    open_room_at(event.starts_at + 5.seconds, event, as: create_admin) { assert_response :forbidden }
  end

  test "จำนวน query ไม่เพิ่มตามจำนวนสินค้าในห้อง (ไม่มี N+1)" do
    counts = [ %w[ก ข], %w[ก ข ค ง จ ฉ] ].map do |names|
      event, *lots = build_event(items: names)
      lots.each { |lot| lot.item.images.attach(io: File.open(file_fixture("photo.png")), filename: "photo.png", content_type: "image/png") }
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      travel_to(event.starts_at + 5.seconds) do
        sign_in @user
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get auction_event_room_path(event) }
        assert_response :success
        assert_equal names.size, lot_rows.size
      end
      queries
    end
    assert_in_delta counts.first, counts.last, 2, "query เพิ่มตามจำนวนสินค้า #{counts.inspect} น่าจะมี N+1"
  end
end
