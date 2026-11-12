require "test_helper"

# NFR-04 / BID-18: ราคาขั้นต่ำ (reserve) ต้องไม่รั่วไปถึงผู้ประมูลในทุกช่องทาง:
#   HTML, JSON, Turbo Stream, log, ข้อความ error
# ใช้เลข reserve ที่ไม่ซ้ำกับราคาอื่น (987654.32) แล้วค้นทุกรูปแบบที่แสดงได้ (987654 / 987,654 / 987.654)
# ครึ่งหลังของ #73 (ราคาที่ผู้ใช้ยื่น) เพิ่มต่อจากนี้เมื่อมีโมเดล Bid (#63): ใช้โครงเดียวกัน
class SecretPriceLeakTest < ActionDispatch::IntegrationTest
  RESERVE = BigDecimal("987654.32")
  LEAK_TOKENS = %w[987654 987,654 987.654].freeze

  setup do
    @user = create_approved_bidder
    @admin = create_admin
    @base = Time.zone.now.change(usec: 0)
    room = Room.create!(name: "ห้องลับ", max_participants: 10, max_items: 5)
    starts = @base + 2.hours
    @event = AuctionEvent.create!(name: "รอบทดสอบราคาลับ", room:, auction_method: auction_methods(:first_price),
                                  starts_at: starts, ends_at: starts + 1.hour)
    @item_a = Item.create!(name: "ของลับ ก", description: "สภาพดี", starting_price: 1000, reserve_price: RESERVE, status: :available)
    @item_b = Item.create!(name: "ของลับ ข", description: "มือสอง", starting_price: 2000, reserve_price: RESERVE + 1, status: :available)
    @lot_a = Lot.create!(auction_event: @event, item: @item_a)
    @lot_b = Lot.create!(auction_event: @event, item: @item_b)
    Participation.create!(user: @user, lot: @lot_a)
    @now = starts + 5.seconds # เริ่มแล้ว: ทุกหน้าเปิดได้
  end

  def leaks_in(text) = LEAK_TOKENS.select { |token| text.to_s.include?(token) }

  def assert_no_leak(text, where)
    assert_empty leaks_in(text), "ราคาขั้นต่ำรั่วที่ #{where}: #{leaks_in(text).inspect}"
  end

  # หน้าทั้งหมดที่ผู้ประมูลเข้าถึงได้ (label => path)
  def bidder_pages
    { "หน้าแรก" => root_path, "รายละเอียดสินค้า" => lot_path(@lot_a), "รายละเอียดสินค้า (ยังไม่เข้าร่วม)" => lot_path(@lot_b),
      "ห้องประมูล" => auction_event_room_path(@event), "การประมูลของฉัน" => my_auctions_path }
  end

  def as_bidder(&block)
    travel_to(@now) do
      sign_in @user
      block.call
    end
  end

  # บันทึก log ทุกชนิด (request, params, SQL, view) ระหว่าง block
  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    logger.level = Logger::DEBUG
    previous = [ Rails.logger, ActiveRecord::Base.logger, ActiveSupport::LogSubscriber.logger, ActionController::Base.logger, ActionView::Base.logger ]
    Rails.logger = ActiveRecord::Base.logger = ActiveSupport::LogSubscriber.logger = ActionController::Base.logger = ActionView::Base.logger = logger
    yield
    io.string
  ensure
    Rails.logger, ActiveRecord::Base.logger, ActiveSupport::LogSubscriber.logger, ActionController::Base.logger, ActionView::Base.logger = previous
  end

  # ---------- HTML ----------

  test "BID-18 HTML: ทุกหน้าของผู้ประมูลไม่มีราคาขั้นต่ำ (รวม attribute และคอมเมนต์ในซอร์ส)" do
    as_bidder do
      bidder_pages.each do |label, path|
        get path
        assert_response :success, label
        assert_no_leak response.body, "HTML ของ #{label}"
        assert_no_leak response.headers.to_h.values.join(" "), "header ของ #{label}"
      end
    end
  end

  test "ตรวจว่า test ไม่ว่างเปล่า: หน้าแสดงสินค้าจริงและ admin เห็นราคาขั้นต่ำได้ (จึงรั่วแล้วจะจับได้)" do
    as_bidder do
      get lot_path(@lot_a)
      assert_includes response.body, "ของลับ ก"
      assert_includes response.body, "1,000 บาท" # ราคาเริ่มต้นแสดงได้
    end
    sign_in @admin
    get admin_item_path(@item_a)
    assert_response :success
    assert leaks_in(response.body).any?, "admin ต้องเห็นราคาขั้นต่ำ (ถ้าไม่เห็น test นี้ตรวจอะไรไม่ได้)"
  end

  # ---------- JSON / format อื่น ----------

  test "BID-18 JSON: ขอ JSON ด้วย Accept, นามสกุล .json หรือ ?format= ไม่ได้ราคาขั้นต่ำ" do
    as_bidder do
      bidder_pages.each do |label, path|
        [ { headers: { "Accept" => "application/json" } },
          { headers: { "Accept" => "*/*" }, suffix: ".json" },
          { headers: {}, suffix: "?format=json" },
          { headers: { "Accept" => "application/xml" } } ].each do |option|
          url = option[:suffix] ? (path + option[:suffix]) : path
          get url, headers: option[:headers]
          assert_no_leak response.body, "JSON/format ของ #{label} (#{url} #{option[:headers]})"
        end
      end
    end
  end

  test "BID-18 JSON: Item แปลงเป็น JSON ไม่มี reserve_price โดยค่าเริ่มต้น" do
    [ @item_a.to_json, @item_a.as_json.to_json, Item.where(id: @item_a.id).to_json, { item: @item_a }.to_json, [ @item_a ].to_json ].each do |json|
      assert_no_leak json, "to_json ของ Item"
      assert_not_includes json, "reserve_price"
    end
  end

  test "NFR-04 JSON: Bid แปลงเป็น JSON ไม่มีจำนวนเงินและตัวตนผู้ยื่นโดยค่าเริ่มต้น (ราคาที่ยื่น เป็นความลับเหมือน reserve)" do
    bid = Bid.new(user: @user, lot: @lot_a, amount: BigDecimal("555123.45"), placed_at: Time.current)
    [ bid.to_json, bid.as_json.to_json, { bid: bid }.to_json, [ bid ].to_json ].each do |json|
      assert_not_includes json, "555123"
      assert_not_includes json, "amount"
      assert_not_includes json, "user_id"
    end
    assert_equal({ "amount" => "555123.45" }, bid.as_json(only: [ :amount ])) # ขอชัดเจนได้
  end

  test "admin ขอ reserve_price ใน JSON ได้เมื่อระบุชัดเจนเท่านั้น" do
    assert_equal({ "reserve_price" => RESERVE.to_s }, @item_a.as_json(only: [ :reserve_price ]))
  end

  # ---------- Turbo Stream ----------

  test "BID-18 Turbo Stream: ขอด้วย Accept ของ Turbo และส่งฟอร์มเข้าร่วม/ยกเลิกแล้วไม่มีราคาขั้นต่ำ" do
    turbo = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    as_bidder do
      bidder_pages.each do |label, path|
        get path, headers: turbo
        assert_no_leak response.body, "Turbo Stream (GET) ของ #{label}"
      end
      post lot_participation_path(@lot_b), headers: turbo
      assert_no_leak response.body, "Turbo Stream (POST เข้าร่วม)"
      assert_no_leak response.headers.to_h.values.join(" "), "header ของ POST เข้าร่วม"
      follow_redirect!
      assert_no_leak response.body, "หน้าหลังเข้าร่วม"
      delete lot_participation_path(@lot_b), headers: turbo
      assert_no_leak response.body, "Turbo Stream (DELETE ยกเลิก)"
    end
  end

  # ---------- log ----------

  test "BID-18 log: ผู้ประมูลเปิดทุกหน้า เข้าร่วม ยกเลิก และเจอ error แล้ว log ไม่มีราคาขั้นต่ำ" do
    log = capture_log do
      as_bidder do
        bidder_pages.each_value { |path| get path }
        post lot_participation_path(@lot_b)
        delete lot_participation_path(@lot_a) # หลังเริ่มแล้วยกเลิกไม่ได้ ได้ข้อความ error
        get lot_path(0) # 404
      end
    end
    assert_includes log, "Started GET", "ต้องมี log จริง (กันผ่านเพราะจับ log ไม่ได้)"
    %w[HomeController#show LotsController#show AuctionRoomsController#show MyAuctionsController#index
       ParticipationsController#create ParticipationsController#destroy].each do |action|
      assert_includes log, "Processing by #{action}", "log ต้องครอบ #{action}"
    end
    assert_no_leak log, "log"
  end

  test "NFR-04 log: พารามิเตอร์ reserve_price และ amount ถูกกรองเป็น [FILTERED]" do
    secret_amount = "555123"
    log = capture_log do
      as_bidder do
        post lot_participation_path(@lot_b), params: { reserve_price: RESERVE.to_s, amount: secret_amount, bid: { amount: secret_amount } }
      end
    end
    assert_includes log, "[FILTERED]"
    assert_no_leak log, "log ของพารามิเตอร์"
    assert_not_includes log, secret_amount
  end

  test "NFR-04 inspect ของ Item ไม่มี reserve_price (ขึ้น log และข้อความ error ได้)" do
    assert_no_leak @item_a.inspect, "Item#inspect"
    assert_includes @item_a.inspect, "[FILTERED]"
    assert_no_leak Lot.includes(:item).find(@lot_a.id).inspect, "Lot#inspect"
  end

  test "NFR-04 ตั้งค่า filter_parameters ครอบ reserve และ amount (รวมพารามิเตอร์ซ้อน)" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
                                             .filter("item" => { "reserve_price" => "1" }, "bid" => { "amount" => "2" }, "name" => "เก็บไว้")
    assert_equal({ "item" => { "reserve_price" => "[FILTERED]" }, "bid" => { "amount" => "[FILTERED]" }, "name" => "เก็บไว้" }, filtered)
  end

  # ---------- ข้อความ error ----------

  test "BID-18 error: 404, 403, ข้อความแจ้งเตือน และ validation ไม่มีราคาขั้นต่ำ" do
    as_bidder do
      get lot_path(0)
      assert_response :not_found
      assert_no_leak response.body, "หน้า 404"

      @lot_b.update!(status: :unsold) # ไม่ pending: เปิดดูไม่ได้
      get lot_path(@lot_b)
      assert_response :not_found
      assert_no_leak response.body, "หน้า 404 ของ lot ที่ปิดแล้ว"

      delete lot_participation_path(@lot_a) # ยกเลิกหลังเริ่มไม่ได้
      follow_redirect!
      assert_no_leak response.body, "flash error ของการยกเลิก"
    end
    errors = Participation.new(user: @user, lot: @lot_a).tap(&:valid?).errors.full_messages.to_sentence
    assert_no_leak errors, "ข้อความ validation ของ Participation"
    bad = Item.new(name: "", starting_price: 1000, reserve_price: 10).tap(&:valid?)
    assert_no_leak bad.errors.full_messages.to_sentence, "ข้อความ validation ของ Item"
  end

  test "BID-18 error: ผู้ประมูลเปิดหน้า admin ของสินค้าไม่ได้ (403) และไม่เห็นราคาขั้นต่ำ" do
    as_bidder do
      [ admin_items_path, admin_item_path(@item_a), edit_admin_item_path(@item_a), "#{admin_item_path(@item_a)}.json" ].each do |path|
        get path
        assert_response :forbidden, path
        assert_no_leak response.body, "หน้า 403 #{path}"
      end
      patch admin_item_path(@item_a), params: { item: { reserve_price: "1" } }
      assert_response :forbidden
      assert_equal RESERVE, @item_a.reload.reserve_price
    end
  end

  test "BID-18 error: ผู้ที่ยังไม่ login ถูกส่งไปหน้า login และไม่เห็นราคาขั้นต่ำ" do
    [ lot_path(@lot_a), auction_event_room_path(@event), admin_item_path(@item_a) ].each do |path|
      get path
      assert_redirected_to(/login/)
      assert_no_leak response.body, "redirect ของ #{path}"
    end
  end
end
