require "test_helper"

# #64 BID-01..05, BID-18, SUSP-03, NFR-03, NFR-05
class PlaceBidTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin
    # สินค้า: ราคาเริ่มต้น 1,000 reserve 1,500 (ตัวอย่างใน requirements/04-bidding.md)
    @item = Item.create!(name: "สินค้าทดสอบ", description: "รายละเอียด", starting_price: 1_000, reserve_price: 1_500)
    @item.approve!(by: @admin)
    starts_at = Time.zone.now.change(usec: 0) + 1.hour # วินาทีเต็ม เพื่อให้ travel_to ตรงขอบเวลาได้พอดี
    @event = AuctionEvent.create!(name: "รอบทดสอบ", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: starts_at, ends_at: starts_at + 2.hours, selected_item_ids: [ @item.id ])
    @lot = @event.lots.sole
    @user = create_approved_bidder(assets: [ { name: "บ้าน", value: "5000" } ], admin: @admin)
    Participation.create!(user: @user, lot: @lot)
  end

  def start_bidding(seconds_after_start = 5)
    travel_to @event.starts_at + seconds_after_start.seconds
  end

  # travel_to ปกติตัดเศษวินาที ใช้ with_usec เมื่อต้องการขอบเวลาที่ละเอียดกว่าวินาที
  def travel_precisely(time, &block) = travel_to(time, with_usec: true, &block)

  def bid(amount, user: @user, lot: @lot)
    PlaceBid.call(user: user, lot: lot, amount: amount)
  end

  def join(user)
    Participation.create!(user: user, lot: @lot)
    user
  end

  # ---- สำเร็จ
  test "ยื่นราคาในช่วงเปิดรับ สำเร็จ และบันทึกเวลาจากนาฬิกาเซิร์ฟเวอร์ละเอียดระดับไมโครวินาที" do
    start_bidding
    result = bid("1800")

    assert result.ok?, result.message
    assert_equal BigDecimal("1800"), result.bid.amount
    assert_equal @user, result.bid.user
    assert_in_delta Clock.now.to_f, result.bid.placed_at.to_f, 0.001
  end

  test "รับตัวเลขคั่นหลักพันและเลขทศนิยม 2 ตำแหน่ง" do
    start_bidding
    assert_equal BigDecimal("1800.50"), bid("1,800.50").bid.amount
  end

  test "ราคาเท่ากับราคาเริ่มต้นและเท่ากับเพดานพอดี ยื่นได้ (ขอบของ BID-05 / BID-04)" do
    other = join(create_approved_bidder(assets: [ { name: "บ้าน", value: "1000" } ], admin: @admin))
    start_bidding
    assert bid("1000", user: other).ok?
    assert bid("5000").ok?
  end

  test "ยื่นราคาต่ำกว่า reserve ได้ (ผู้ใช้ไม่รู้ reserve) ระบบแค่ไม่ขายตอนปิด" do
    start_bidding
    assert bid("1100").ok?
  end

  # ---- BID-01 / NFR-05
  test "BID-01: ยื่นครั้งที่สองถูกปฏิเสธ และราคาแรกไม่เปลี่ยน" do
    start_bidding
    assert bid("1800").ok?

    second = bid("2500")

    assert_not second.ok?
    assert_equal :already_bid, second.error
    assert_equal [ BigDecimal("1800") ], Bid.where(user: @user, lot: @lot).pluck(:amount)
  end

  # ---- BID-02 เวลา
  test "BID-02: ก่อนเริ่มยื่นไม่ได้" do
    travel_to @event.starts_at - 1.second
    result = bid("1800")
    assert_equal :not_started, result.error
    assert_equal 0, Bid.count
  end

  test "BID-02: ที่เวลาเริ่มพอดีและที่ 30 วินาทีพอดี ยื่นได้ (นับทั้งต้นและปลายช่วง)" do
    other = join(create_approved_bidder(assets: [ { name: "บ้าน", value: "5000" } ], admin: @admin))
    travel_to @event.starts_at
    assert bid("1800").ok?
    travel_to @event.starts_at + 30.seconds
    assert bid("1900", user: other).ok?
  end

  test "BID-02: เกิน 30 วินาทีแม้เพียงเสี้ยววินาที ถูกปฏิเสธ" do
    travel_precisely @event.starts_at + 30.seconds + 0.001.seconds
    result = bid("1800")
    assert_equal :closed, result.error
    assert_equal 0, Bid.count
  end

  test "NFR-03: ช่วงเวลามาจากวิธีประมูลของ event ไม่ใช่เลข 30 ฝังในโค้ด" do
    @event.auction_method.update!(bidding_seconds: 10)
    travel_to @event.starts_at + 11.seconds
    assert_equal :closed, bid("1800").error
  end

  test "ถึงเวลาเริ่มแต่ job ยังไม่ทำงาน: ยื่นราคาได้และ event เริ่มให้ (สินค้าเป็นอยู่ระหว่างประมูล)" do
    start_bidding
    assert @event.reload.scheduled?

    assert bid("1800").ok?

    assert @event.reload.bidding?
    assert @item.reload.in_auction?
  end

  test "event ที่สรุปผลหรือถูกยกเลิกแล้ว ยื่นไม่ได้" do
    start_bidding
    @event.start!
    @event.update_columns(status: "settled")
    assert_equal :closed, bid("1800").error
  end

  test "lot ที่ไม่ได้รอการประมูลแล้ว (เช่นถูกเอาออก) ยื่นไม่ได้" do
    start_bidding
    @lot.update_columns(status: "cancelled")
    assert_equal :closed, bid("1800").error
  end

  # ---- BID-03 สิทธิ์
  test "BID-03: ต้องเข้าร่วมสินค้านั้นไว้ก่อน" do
    stranger = create_approved_bidder(admin: @admin)
    start_bidding
    assert_equal :not_joined, bid("1800", user: stranger).error
  end

  test "BID-03: ยกเลิกการเข้าร่วมแล้วยื่นไม่ได้" do
    travel_to @event.starts_at - 1.minute
    Participation.active.find_by!(user: @user, lot: @lot).cancel!
    start_bidding
    assert_equal :not_joined, bid("1800").error
  end

  test "BID-03: ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติยื่นไม่ได้" do
    waiting = create_bidder
    start_bidding
    assert_equal :not_qualified, bid("1800", user: waiting).error
  end

  test "SUSP-03: ผู้ที่ถูกระงับยื่นไม่ได้" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    start_bidding
    result = bid("1800")
    assert_equal :suspended, result.error
    assert_equal 0, Bid.count
  end

  test "admin ยื่นราคาไม่ได้" do
    start_bidding
    assert_equal :not_bidder, bid("1800", user: @admin).error
  end

  # ---- BID-04 / BID-05 ช่วงราคา
  test "BID-05: ต่ำกว่าราคาเริ่มต้นถูกปฏิเสธ พร้อมบอกราคาเริ่มต้น" do
    start_bidding
    result = bid("999.99")
    assert_equal :invalid_amount, result.error
    assert_includes result.message, "1,000"
  end

  test "BID-04: เกินวงเงินทรัพย์สินรวมถูกปฏิเสธ พร้อมบอกวงเงิน" do
    start_bidding
    result = bid("5000.01")
    assert_equal :invalid_amount, result.error
    assert_includes result.message, "5,000"
  end

  test "BID-04: วงเงินนับต่อครั้ง ไม่รวมสะสมข้ามสินค้า" do
    second_item = Item.create!(name: "สินค้าที่สอง", description: "x", starting_price: 1_000, reserve_price: 1_000).tap { |i| i.approve!(by: @admin) }
    event2 = AuctionEvent.create!(name: "รอบที่สอง", room: rooms(:old_room).tap { |r| r.update_columns(archived_at: nil) },
                                  auction_method: auction_methods(:first_price), starts_at: @event.starts_at, ends_at: @event.ends_at,
                                  selected_item_ids: [ second_item.id ])
    lot2 = event2.lots.sole
    Participation.create!(user: @user, lot: lot2)
    start_bidding

    assert bid("5000").ok?
    assert bid("5000", lot: lot2).ok?, "ยื่นสินค้าที่สองด้วยวงเงินเต็มอีกครั้งได้ (ไม่รวมสะสม)"
  end

  test "ราคาที่ไม่ใช่ตัวเลขบาทที่ถูกต้อง ถูกปฏิเสธ" do
    start_bidding
    [ "", " ", "abc", "-100", "0", "1e3", "1800.555", "1,8,0,0x", nil, "１８００" ].each do |raw|
      result = bid(raw)
      assert_equal :invalid_amount, result.error, "#{raw.inspect} ควรถูกปฏิเสธ"
    end
    assert_equal 0, Bid.count
  end

  # ---- BID-18 ความลับของ reserve
  test "BID-18: ข้อความ error ทุกแบบไม่เอ่ยถึง reserve หรือค่า 1,500" do
    stranger = create_approved_bidder(admin: @admin)
    waiting = create_bidder
    messages = []

    travel_to @event.starts_at - 1.second
    messages << bid("1800").message
    start_bidding
    messages << bid("1800", user: stranger).message
    messages << bid("1800", user: waiting).message
    messages << bid("1").message
    messages << bid("99999").message
    messages << bid("abc").message
    bid("1800")
    messages << bid("2500").message
    travel_to @event.starts_at + 31.seconds
    messages << bid("1800", user: stranger).message

    assert_equal 8, messages.size
    messages.each do |message|
      assert_not_includes message.downcase, "reserve"
      assert_not_includes message, "ขั้นต่ำ"
      assert_not_includes message, "1,500"
    end
  end

  # ---- ราคาของคนอื่นเป็นความลับ
  test "ข้อความ error ไม่เปิดเผยราคาหรือจำนวนผู้ยื่นของคนอื่น" do
    other = join(create_approved_bidder(admin: @admin))
    start_bidding
    bid("4321", user: other)

    result = bid("1")
    assert_not_includes result.message, "4,321"
    assert_not_includes result.message, "4321"
  end

  # ---- placed_at ใช้ตัดสินราคาเท่ากัน
  test "BID-07: ผู้ยื่นก่อนมี placed_at เร็วกว่า" do
    other = join(create_approved_bidder(admin: @admin))
    travel_precisely @event.starts_at + 5.2.seconds
    first = bid("1800").bid
    travel_precisely @event.starts_at + 9.7.seconds
    second = bid("1800", user: other).bid

    assert_operator first.placed_at, :<, second.placed_at
    assert_equal [ first, second ], @lot.bids.for_settlement.to_a
  end
end
