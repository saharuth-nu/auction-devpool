require "test_helper"

# #56 EVT-09, EVT-12, BID-11, BID-17
class AdminAuctionEventBidsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    @item = Item.create!(name: "นาฬิกาแอดมิน", description: "x", starting_price: 1_000, reserve_price: 1_500).tap { |i| i.approve!(by: @admin) }
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = AuctionEvent.create!(name: "รอบดูราคา", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: @starts_at, ends_at: @starts_at + 2.hours, selected_item_ids: [ @item.id ])
    @lot = @event.lots.sole
    @ana = create_approved_bidder(admin: @admin, fullname: "อนงค์ ใจดี")
    @bua = create_approved_bidder(admin: @admin, fullname: "บุญมี ศรีสุข")
    [ @ana, @bua ].each { |u| Participation.create!(user: u, lot: @lot) }
  end

  def place(user, amount, at: 5.seconds)
    travel_to(@starts_at + at, with_usec: true) { PlaceBid.call(user: user, lot: @lot, amount: amount) }
  end

  def bids_page = bids_admin_auction_event_path(@event)

  test "EVT-09: admin เห็นราคาของทุกคน เรียงผู้ชนะก่อน พร้อมชื่อ และเวลาละเอียดระดับมิลลิวินาที" do
    place(@ana, "1800", at: 9.7.seconds)
    place(@bua, "2200", at: 5.2.seconds)
    travel_to(@starts_at + 10.seconds) do
      sign_in(@admin)
      get bids_page

      assert_response :success
      rows = css_select("tbody tr").map { |tr| tr.text.squish }
      assert_equal 2, rows.size
      assert_match(/1 บุญมี ศรีสุข.*2,200 บาท/, rows.first)
      assert_match(/2 อนงค์ ใจดี.*1,800 บาท/, rows.last)
      assert_match(/\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2}\.\d{3}/, rows.first)
    end
  end

  test "EVT-09: ดูได้หลังปิดและสรุปผลแล้ว พร้อมป้ายผู้ชนะ และ reserve (admin เห็นได้)" do
    place(@ana, "1800")
    place(@bua, "2200")
    travel_to(@starts_at + 31.seconds) do
      @event.reload.start!
      @event.reload.settle!
      sign_in(@admin)
      get bids_page

      assert_response :success
      assert_select ".ui-badge--success", "ผู้ชนะ"
      assert_select ".ui-badge--success", "ขายได้"
      assert_match(/1,500 บาท/, response.body) # reserve เป็นข้อมูลของ admin
    end
  end

  test "BID-17: ราคาของผู้ถูกระงับยังแสดงพร้อมป้าย และนับเป็นผู้ชนะได้" do
    place(@ana, "2500")
    travel_to(@starts_at + 6.seconds) { @ana.suspend!(by: @admin, reason: "ทดสอบ") }
    travel_to(@starts_at + 31.seconds) do
      @event.reload.start!
      @event.reload.settle!
      sign_in(@admin)
      get bids_page
      assert_select ".ui-badge--danger", /บัญชีถูกระงับ/
      assert_select ".ui-badge--success", "ผู้ชนะ"
    end
  end

  test "ยังไม่มีผู้ยื่นราคา แสดงข้อความ" do
    sign_in(@admin)
    get bids_page
    assert_response :success
    assert_select ".ui-table__message", "ยังไม่มีผู้ยื่นราคา"
  end

  # ---- EVT-12: บันทึกการเข้าดู
  test "EVT-12: เปิดดูในช่วงเปิดรับราคา บันทึก admin, lot, เวลา และช่วง open" do
    place(@ana, "1800")
    travel_to(@starts_at + 10.seconds) do
      sign_in(@admin)
      assert_difference -> { AuditLog.where(action: "bids.view").count }, 1 do
        get bids_page
      end
    end
    log = AuditLog.where(action: "bids.view").last
    assert_equal @admin, log.admin
    assert_equal @lot, log.target
    assert_equal "open", log.change_set["phase"]
    assert_equal 1, log.change_set["bids_count"]
    assert_in_delta Time.current.to_f, log.created_at.to_f, 60 * 60 * 2
  end

  test "EVT-12: เปิดดูหลังปิดรับราคา บันทึกช่วง closed ทุกครั้งที่เปิด" do
    place(@ana, "1800")
    travel_to(@starts_at + 31.seconds) do
      sign_in(@admin)
      get bids_page
      get bids_page
    end
    logs = AuditLog.where(action: "bids.view")
    assert_equal 2, logs.count
    assert_equal [ "closed" ], logs.map { |l| l.change_set["phase"] }.uniq
  end

  test "EVT-12: บันทึกต่อ lot (event ที่มี 2 สินค้า ได้ 2 รายการ)" do
    second = Item.create!(name: "ชิ้นที่สอง", description: "x", starting_price: 1_000, reserve_price: 1_000).tap { |i| i.approve!(by: @admin) }
    event = AuctionEvent.create!(name: "รอบสอง", room: rooms(:old_room).tap { |r| r.update_columns(archived_at: nil) },
                                 auction_method: auction_methods(:first_price), starts_at: @starts_at, ends_at: @starts_at + 1.hour,
                                 selected_item_ids: [ second.id ])
    sign_in(@admin)
    assert_difference -> { AuditLog.where(action: "bids.view").count }, 1 do
      get bids_admin_auction_event_path(event)
    end
  end

  test "ลิงก์ 'ดูราคาที่ยื่น' อยู่ในรายการเฉพาะ event ที่เริ่มแล้ว" do
    sign_in(@admin)
    get admin_auction_events_path
    assert_select "a[href=?]", bids_page, count: 0 # ยังไม่เริ่ม

    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      get admin_auction_events_path
      assert_select "a[href=?]", bids_page, text: "ดูราคาที่ยื่น"
    end
  end

  # ---- ผู้ใช้ทั่วไปเห็นไม่ได้ (BID-11)
  test "BID-11: ผู้ประมูลเปิดหน้านี้ไม่ได้ (403) และไม่ถูกบันทึกว่าเปิดดู" do
    place(@ana, "1800")
    sign_in(@bua)
    assert_no_difference -> { AuditLog.count } do
      get bids_page
    end
    assert_response :forbidden
    assert_not_includes response.body, "1,800"
  end

  test "ผู้ที่ยังไม่ login ถูกส่งไปหน้า login ของ admin" do
    get bids_page
    assert_redirected_to admin_login_path
  end
end
