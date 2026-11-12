require "test_helper"

# #65 BID-01..05, BID-11, BID-18, BID-20, BID-21, USR-13
class BidsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    # สินค้า: ราคาเริ่มต้น 1,000 reserve 1,500 (ค่า 1,500 ต้องไม่โผล่ในหน้าใดของผู้ใช้)
    @item = Item.create!(name: "นาฬิกาทดสอบ", description: "รายละเอียด", starting_price: 1_000, reserve_price: 1_500)
    @item.approve!(by: @admin)
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = AuctionEvent.create!(name: "รอบยื่นราคา", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: @starts_at, ends_at: @starts_at + 2.hours, selected_item_ids: [ @item.id ])
    @lot = @event.lots.sole
    @user = create_approved_bidder(assets: [ { name: "บ้าน", value: "5000" } ], admin: @admin)
    @rival = create_approved_bidder(assets: [ { name: "บ้าน", value: "9000" } ], admin: @admin)
    [ @user, @rival ].each { |u| Participation.create!(user: u, lot: @lot) }
  end

  def room_path_for = auction_event_room_path(@event)

  def during_bidding(seconds = 5, &block)
    travel_to(@starts_at + seconds.seconds, &block)
  end

  def bid_as(user, amount, lot: @lot)
    sign_in(user)
    post lot_bid_path(lot), params: { bid: { amount: amount } }
  end

  # ---- ฟอร์ม (BID-20, BID-21)
  test "BID-21: ในห้องที่เปิดรับราคา ฟอร์มแสดงช่วงราคาที่ยื่นได้ (ราคาเริ่มต้น ถึง เพดานทรัพย์สิน)" do
    during_bidding do
      sign_in(@user)
      get room_path_for

      assert_response :success
      assert_select "form[action=?]", lot_bid_path(@lot)
      assert_select ".ui-bid-form__range", /1,000 บาท.*5,000 บาท/m
      assert_select "form[data-bid-form-min-value=?]", "1000.0"
      assert_select "form[data-bid-form-max-value=?]", "5000.0"
    end
  end

  test "BID-20: มีหน้าต่างยืนยันที่บอกว่ายื่นแล้วแก้ไขหรือถอนไม่ได้ และยังเป็นแค่ขั้นฝั่งเบราว์เซอร์" do
    during_bidding do
      sign_in(@user)
      get room_path_for

      assert_select "dialog.ui-dialog[data-bid-form-target=dialog]" do
        assert_select ".ui-dialog__title", "ยืนยันการยื่นราคา"
        assert_select ".ui-dialog__message", "ยื่นแล้วแก้ไขหรือถอนไม่ได้"
        assert_select "[data-bid-form-target=confirmAmount]"
        assert_select "button[type=submit]", "ยืนยันยื่นราคา"
      end
      assert_select "button[data-action=?]", "bid-form#review", text: "ตรวจสอบและยื่นราคา"
    end
  end

  test "วงเงินต่ำกว่าราคาเริ่มต้น ไม่แสดงฟอร์ม และบอกเหตุผล" do
    poor = create_approved_bidder(assets: [ { name: "เงินสด", value: "500" } ], admin: @admin)
    Participation.create!(user: poor, lot: @lot)

    during_bidding do
      sign_in(poor)
      get room_path_for
      assert_select "form[action=?]", lot_bid_path(@lot), count: 0
      assert_select ".ui-bid-mine--none", /วงเงินของคุณต่ำกว่าราคาเริ่มต้น/
    end
  end

  test "ยังไม่ได้เข้าร่วมสินค้า ไม่มีช่องยื่นราคา" do
    stranger = create_approved_bidder(admin: @admin)
    during_bidding do
      sign_in(stranger)
      get room_path_for
      assert_select "form[action=?]", lot_bid_path(@lot), count: 0
    end
  end

  test "ก่อนเริ่มและหลังปิดรับราคา ไม่มีฟอร์ม (หลังปิดบอกว่าไม่ได้ยื่น)" do
    travel_to(@starts_at + 31.seconds) do
      sign_in(@user)
      get room_path_for
      assert_select "form[action=?]", lot_bid_path(@lot), count: 0
      assert_select ".ui-bid-mine--none", "คุณไม่ได้ยื่นราคา"
    end
  end

  # ---- ยื่นสำเร็จ / ยื่นครั้งเดียว (BID-01)
  test "ยื่นราคาสำเร็จ กลับห้องพร้อมข้อความ และบันทึกราคาของผู้ใช้คนนั้น" do
    during_bidding do
      bid_as(@user, "1,800")

      assert_redirected_to room_path_for
      follow_redirect!
      assert_select ".ui-alert--success", /1,800 บาท.*แก้ไขหรือถอนไม่ได้/m
    end
    bid = Bid.find_by!(user: @user, lot: @lot)
    assert_equal BigDecimal("1800"), bid.amount
  end

  test "USR-13: ยื่นแล้ว ห้องแสดงราคาของตัวเอง และไม่มีฟอร์มให้ยื่นซ้ำ" do
    during_bidding do
      bid_as(@user, "1800")
      get room_path_for

      assert_select ".ui-bid-mine", /คุณยื่นราคาแล้ว.*1,800 บาท/m
      assert_select "form[action=?]", lot_bid_path(@lot), count: 0
    end
  end

  test "BID-01: ยื่นซ้ำถูกปฏิเสธด้วยข้อความ และราคาแรกไม่เปลี่ยน" do
    during_bidding do
      bid_as(@user, "1800")
      post lot_bid_path(@lot), params: { bid: { amount: "2500" } }

      assert_redirected_to room_path_for
      follow_redirect!
      assert_select ".ui-alert--error", /ยื่นราคาสินค้านี้แล้ว/
    end
    assert_equal [ BigDecimal("1800") ], Bid.where(user: @user, lot: @lot).pluck(:amount)
  end

  # ---- ถูกปฏิเสธที่เซิร์ฟเวอร์ (ขั้นฝั่งเบราว์เซอร์ไม่ใช่ตัวตัดสิน)
  test "ราคานอกช่วงถูกปฏิเสธที่เซิร์ฟเวอร์แม้ส่ง request ตรง" do
    during_bidding do
      bid_as(@user, "999")
      follow_redirect!
      assert_select ".ui-alert--error", /ไม่ต่ำกว่า 1,000 บาท/

      post lot_bid_path(@lot), params: { bid: { amount: "5001" } }
      follow_redirect!
      assert_select ".ui-alert--error", /ไม่เกินวงเงินของคุณ 5,000 บาท/

      post lot_bid_path(@lot), params: { bid: { amount: "abc" } }
      follow_redirect!
      assert_select ".ui-alert--error", /ตัวเลขบาท/
    end
    assert_equal 0, Bid.count
  end

  test "BID-02: ยื่นหลังเกิน 30 วินาทีถูกปฏิเสธ แม้หน้าห้องเปิดค้างไว้" do
    travel_to(@starts_at + 31.seconds) do
      bid_as(@user, "1800")
      assert_redirected_to room_path_for
      follow_redirect!
      assert_select ".ui-alert--error", /ปิดรับราคาแล้ว/
    end
    assert_equal 0, Bid.count
  end

  test "ยังไม่ได้เข้าร่วม ยื่นตรงๆ ไม่ได้" do
    stranger = create_approved_bidder(admin: @admin)
    during_bidding do
      bid_as(stranger, "1800")
      follow_redirect!
      assert_select ".ui-alert--error", /เข้าร่วมประมูลสินค้านี้ก่อน/
    end
    assert_equal 0, Bid.count
  end

  test "event สรุปผลแล้ว ยื่นจากหน้าเก่าได้ข้อความ ไม่ใช่ error 500" do
    travel_to(@starts_at + 31.seconds) do
      @event.reload.start!
      @event.reload.settle!
      bid_as(@user, "1800")
      assert_redirected_to my_auctions_path
      follow_redirect!
      assert_select ".ui-alert--error", /ปิดรับราคาแล้ว/
    end
    assert_equal 0, Bid.count
  end

  test "ผู้ที่ยังไม่ผ่านการตรวจคุณสมบัติถูกส่งไปหน้าสถานะ ไม่มีราคาถูกบันทึก" do
    waiting = create_bidder
    during_bidding do
      bid_as(waiting, "1800")
      assert_redirected_to qualification_path
    end
    assert_equal 0, Bid.count
  end

  test "SUSP-03: ผู้ที่ถูกระงับระหว่างที่ login อยู่ ยื่นราคาไม่ได้ (session หมดผลทันที)" do
    during_bidding do
      sign_in(@user)
      @user.suspend!(by: @admin, reason: "ทดสอบ")

      post lot_bid_path(@lot), params: { bid: { amount: "1800" } }

      assert_redirected_to login_path
    end
    assert_equal 0, Bid.count
  end

  test "SUSP-03: ผู้ถูกระงับ login ใหม่ไม่ได้ จึงยื่นไม่ได้" do
    @user.suspend!(by: @admin, reason: "ทดสอบ")
    during_bidding do
      bid_as(@user, "1800")
      assert_redirected_to login_path
    end
    assert_equal 0, Bid.count
  end

  test "ผู้ที่ยังไม่ login และ admin ยื่นราคาไม่ได้" do
    post lot_bid_path(@lot), params: { bid: { amount: "1800" } }
    assert_redirected_to login_path

    sign_in(@admin)
    post lot_bid_path(@lot), params: { bid: { amount: "1800" } }
    assert_response :forbidden
    assert_equal 0, Bid.count
  end

  # ---- ความลับ (BID-11, BID-18, NFR-04)
  test "BID-11: หน้าห้องของผู้ใช้หนึ่ง ไม่มีราคาที่ผู้อื่นยื่น" do
    during_bidding do
      bid_as(@rival, "4321")
      delete logout_path
      sign_in(@user)
      get room_path_for
      follow_redirect! if response.redirect?

      assert_response :success
      assert_not_includes response.body, "4,321"
      assert_not_includes response.body, "4321"
      assert_select ".ui-bid-form__range" # ผู้ใช้คนนี้ยังยื่นได้ (ไม่รู้ว่ามีคนยื่นแล้ว)
    end
  end

  test "BID-18: ทุกหน้าที่ผู้ใช้เห็นก่อนและหลังยื่นราคา ไม่มี reserve หรือค่า 1,500" do
    pages = []
    during_bidding do
      sign_in(@user)
      get room_path_for
      pages << response.body
      get lot_path(@lot)
      pages << response.body
      post lot_bid_path(@lot), params: { bid: { amount: "1100" } }
      pages << response.body
      follow_redirect!
      pages << response.body
      get my_auctions_path
      pages << response.body
      post lot_bid_path(@lot), params: { bid: { amount: "1,200" } } # ซ้ำ
      follow_redirect!
      pages << response.body
    end

    pages.each do |html|
      assert_not_includes html.downcase, "reserve"
      assert_not_includes html, "ขั้นต่ำ"
      assert_not_includes html, "1,500"
    end
  end

  test "NFR-04: ราคาที่ยื่น (พารามิเตอร์ amount) ถูกกรองออกจาก log" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
                                              .filter("bid" => { "amount" => "1800" }, "name" => "x")
    assert_equal "[FILTERED]", filtered["bid"]["amount"]
    assert_equal "x", filtered["name"]
  end
end
