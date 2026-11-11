require "test_helper"

# #73 NFR-04 / BID-18: reserve และราคาที่คนอื่นยื่นต้องไม่รั่วไปถึงผู้ประมูลทุกช่องทาง
# (HTML, JSON, Turbo Stream, ข้อความ error, log, broadcast)
class NoLeakTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  RESERVE = "7,654"      # รูปแบบแสดงผล
  RESERVE_RAW = "7654"   # รูปแบบดิบ
  OTHER = "4,321"
  OTHER_RAW = "4321"
  SECRETS = [ RESERVE, RESERVE_RAW, OTHER, OTHER_RAW ].freeze

  setup do
    # ตรวจหน้าที่ผู้ใช้เห็นจริงใน production (หน้า error ไทย) ไม่ใช่หน้า debug ของ development
    @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
    @admin = create_admin
    @item = Item.create!(name: "สินค้าลับ", description: "x", starting_price: 1_000, reserve_price: 7_654).tap { |i| i.approve!(by: @admin) }
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = AuctionEvent.create!(name: "รอบลับ", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: @starts_at, ends_at: @starts_at + 2.hours, selected_item_ids: [ @item.id ])
    @lot = @event.lots.first
    @me = create_approved_bidder(assets: [ { name: "บ้าน", value: "50000" } ], admin: @admin)
    @rival = create_approved_bidder(assets: [ { name: "บ้าน", value: "50000" } ], admin: @admin)
    [ @me, @rival ].each { |u| Participation.create!(user: u, lot: @lot) }
  end

  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed }

  def assert_clean(text, where)
    SECRETS.each { |s| assert_not_includes text, s, "#{where} รั่วค่า #{s}" }
    assert_not_includes text.downcase, "reserve", "#{where} เอ่ยถึง reserve"
  end

  def pages_for_bidder
    [ root_path, my_auctions_path, results_path, lot_path(@lot), auction_event_room_path(@event) ]
  end

  def crawl(formats: [ nil ])
    pages_for_bidder.flat_map do |path|
      formats.map do |fmt|
        get path, headers: (fmt ? { "Accept" => fmt } : {})
        [ "#{path} (#{fmt || 'html'})", response.body ]
      end
    end
  end

  test "NFR-04: หน้าทุกหน้าของผู้ประมูลไม่มี reserve หรือราคาคนอื่น ก่อนเริ่ม ระหว่างประมูล และหลังสรุปผล" do
    sign_in(@me)
    crawl.each { |where, body| assert_clean(body, "ก่อนเริ่ม #{where}") }

    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      PlaceBid.call(user: @rival, lot: @lot, amount: OTHER_RAW)
      crawl.each { |where, body| assert_clean(body, "ระหว่างประมูล #{where}") }
    end

    travel_to(@starts_at + 40.seconds) do
      @event.reload.settle! # rival 4,321 < reserve → ไม่ขาย
      crawl.each { |where, body| assert_clean(body, "หลังสรุป #{where}") }
    end
  end

  test "NFR-04: ขอ JSON หรือ Turbo Stream ก็ไม่เห็นข้อมูลลับ (ไม่มีรูปแบบอื่นนอกจาก HTML)" do
    sign_in(@me)
    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      PlaceBid.call(user: @rival, lot: @lot, amount: OTHER_RAW)
      crawl(formats: [ "application/json", "text/vnd.turbo-stream.html" ]).each do |where, body|
        assert_clean(body, where)
      end
      get auction_event_room_path(@event, format: :json)
      assert_includes [ 404, 406 ], response.status
    end
  end

  test "NFR-04: ข้อความ error ของการยื่นราคาไม่บอกว่าถึง reserve หรือไม่ และไม่บอกราคาคนอื่น" do
    sign_in(@me)
    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      PlaceBid.call(user: @rival, lot: @lot, amount: OTHER_RAW)
      [ "500", "99999999", "abc", "" ].each do |amount|
        post lot_bid_path(@lot), params: { bid: { amount: amount } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        follow_redirect! if response.redirect?
        assert_clean(response.body, "error amount=#{amount.inspect}")
      end
      assert_equal 0, Bid.where(user: @me).count
      # ยื่นสำเร็จ: ผลตอบรับไม่บอกว่าถึง reserve หรือไม่
      post lot_bid_path(@lot), params: { bid: { amount: "9000" } }
      follow_redirect!
      assert_clean(response.body, "หลังยื่นสำเร็จ")
    end
  end

  test "NFR-04: log ไม่เก็บราคาที่ยื่น" do
    sign_in(@me)
    io = StringIO.new
    original = ActionController::Base.logger
    ActionController::Base.logger = ActiveSupport::Logger.new(io)
    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      post lot_bid_path(@lot), params: { bid: { amount: "3456" } }
    end
    ActionController::Base.logger = original
    assert_includes io.string, "[FILTERED]"
    assert_not_includes io.string, "3456"
  ensure
    ActionController::Base.logger = original
  end

  test "NFR-04: ข้อความ broadcast ของห้องไม่มีข้อมูลลับ" do
    messages = capture_broadcasts(@event.to_gid_param) do
      travel_to(@starts_at + 1.second) { @event.reload.start! }
    end
    messages.each { |m| assert_clean(m, "broadcast") }
  end
end
