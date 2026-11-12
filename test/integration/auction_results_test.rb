require "test_helper"

# #61 USR-11..15, USR-17 · #68 BID-11, BID-12, BID-18, BID-19
class AuctionResultsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    # A: เริ่มต้น 1,000 reserve 1,500 · B: เริ่มต้น 1,000 reserve 3,000 · C: เริ่มต้น 1,000 reserve 1,000
    @a = make_item("สินค้า A", 1_000, 1_500)
    @b = make_item("สินค้า B", 1_000, 3_000)
    @c = make_item("สินค้า C", 1_000, 1_000)
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = AuctionEvent.create!(name: "รอบผล", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: @starts_at, ends_at: @starts_at + 2.hours, selected_item_ids: [ @a, @b, @c ].map(&:id))
    @lot_a, @lot_b, @lot_c = @event.lots.order(:id).to_a
    @ana = create_approved_bidder(assets: [ { name: "บ้าน", value: "9000" } ], admin: @admin, fullname: "อนงค์ ชนะเลิศ")
    @bua = create_approved_bidder(assets: [ { name: "บ้าน", value: "9000" } ], admin: @admin, fullname: "บุญมี แพ้ภัย")
    @cara = create_approved_bidder(assets: [ { name: "บ้าน", value: "9000" } ], admin: @admin, fullname: "คมคาย ไม่ยื่น")
    join(@ana, @lot_a)
    join(@bua, @lot_a, @lot_b)
    join(@cara, @lot_c)
  end

  def make_item(name, start, reserve)
    Item.create!(name: name, description: "x", starting_price: start, reserve_price: reserve).tap { |i| i.approve!(by: @admin) }
  end

  def join(user, *lots)
    lots.each { |lot| Participation.create!(user: user, lot: lot) }
  end

  def place(user, lot, amount)
    travel_to(@starts_at + 5.seconds) { PlaceBid.call(user: user, lot: lot, amount: amount) }
  end

  def settle!
    travel_to(@starts_at + 31.seconds) { @event.reload.start!; @event.reload.settle! }
  end

  def settled_scenario
    place(@ana, @lot_a, "1800")
    place(@bua, @lot_a, "1700")
    place(@bua, @lot_b, "2500") # ต่ำกว่า reserve 3,000 → ไม่ขาย
    settle!
  end

  def results_path_for = auction_event_results_path(@event)

  def view_results(user)
    sign_in(user)
    get results_path_for
  end

  def row(label) = css_select("tbody tr").find { |tr| tr.text.include?(label) }&.text&.squish

  # ---- USR-11 / USR-12 / USR-13
  test "USR-11: ผู้ชนะเห็นว่า 'คุณชนะ' พร้อมราคาที่ชนะและราคาที่ตนยื่น" do
    settled_scenario
    view_results(@ana)

    assert_response :success
    assert_equal "สินค้า A คุณชนะ 1,800 บาท 1,800 บาท", row("สินค้า A")
  end

  test "USR-12/BID-12: ผู้ไม่ชนะเห็นราคาผู้ชนะ และราคาของตัวเอง แต่ไม่รู้ว่าใครชนะ" do
    settled_scenario
    view_results(@bua)

    assert_equal "สินค้า A ไม่ชนะ 1,800 บาท 1,700 บาท", row("สินค้า A")
    assert_not_includes response.body, @ana.username
    assert_not_includes response.body, "อนงค์"
  end

  test "USR-13/BID-11: ผู้ใช้ไม่เห็นราคาที่คนอื่นยื่น (ไม่ใช่ราคาผู้ชนะ)" do
    settled_scenario
    view_results(@ana)

    assert_not_includes response.body, "1,700" # ราคาที่ bua ยื่นใน lot A
    assert_not_includes response.body, "2,500" # ราคาที่ bua ยื่นใน lot B
    assert_nil row("สินค้า B"), "ana ไม่ได้เข้าร่วม lot B จึงไม่เห็นผลของ lot นั้น"
  end

  test "BID-19: ไม่ขาย แสดงเพียง 'ไม่ขาย' ไม่มีราคาสูงสุด จำนวนผู้ยื่น หรือเหตุผล" do
    settled_scenario
    view_results(@bua)

    assert_equal "สินค้า B ไม่ขาย - 2,500 บาท", row("สินค้า B") # มีเฉพาะราคาที่ bua ยื่นเอง
    %w[ต่ำกว่า เหตุผล ผู้ยื่น จำนวนผู้ reserve].each { |word| assert_not_includes response.body.downcase, word }
  end

  test "BID-19: ไม่มีผู้ยื่นเลย ก็แสดงเหมือนกัน และผู้เข้าร่วมที่ไม่ยื่นเห็น 'ไม่ได้ยื่นราคา'" do
    settled_scenario
    view_results(@cara)

    assert_equal "สินค้า C ไม่ขาย - ไม่ได้ยื่นราคา", row("สินค้า C")
  end

  test "BID-18: หน้าผลไม่มี reserve หรือค่า 1,500 / 3,000 ของทุกคน" do
    settled_scenario
    [ @ana, @bua, @cara ].each do |user|
      delete logout_path
      view_results(user)
      assert_not_includes response.body.downcase, "reserve"
      assert_not_includes response.body, "ขั้นต่ำ"
      assert_not_includes response.body, "1,500"
      assert_not_includes response.body, "3,000"
    end
  end

  # ---- USR-14 / USR-15
  test "USR-15: ผู้ชนะเห็นข้อความแจ้งผล แต่ไม่มีปุ่มชำระเงิน" do
    settled_scenario
    view_results(@ana)

    assert_select ".ui-alert--success", /คุณชนะการประมูล/
    assert_select "button, a.ui-btn", text: /ชำระ/, count: 0
  end

  test "ผู้ที่ไม่ชนะไม่เห็นข้อความแสดงความยินดี" do
    settled_scenario
    view_results(@bua)
    assert_select ".ui-alert--success", count: 0
  end

  test "USR-14: แจ้งผลที่หน้าเท่านั้น ไม่มี mailer ของการประมูล" do
    settled_scenario
    assert_equal 0, ActionMailer::Base.deliveries.size
    assert_empty Dir[Rails.root.join("app/mailers/*auction*")]
  end

  # ---- สิทธิ์การเข้าถึง
  test "ผู้ที่ไม่ได้เข้าร่วม event นั้นได้ 404" do
    settled_scenario
    stranger = create_approved_bidder(admin: @admin)
    view_results(stranger)
    assert_response :not_found
  end

  test "การเข้าร่วมที่ยกเลิกก่อนเริ่มไม่นับว่าเข้าร่วม" do
    stranger = create_approved_bidder(admin: @admin)
    join(stranger, @lot_c)
    Participation.active.find_by!(user: stranger, lot: @lot_c).cancel!
    settle!
    view_results(stranger)
    assert_response :not_found
  end

  test "event ที่ยังไม่สรุปผล ไปการประมูลของฉันพร้อมข้อความ" do
    view_results(@ana)
    assert_redirected_to my_auctions_path
    follow_redirect!
    assert_select ".ui-alert--error", /ยังไม่สรุปผล/
  end

  test "event ที่ถูกยกเลิกไม่มีผล (404)" do
    @event.cancel!
    view_results(@ana)
    assert_response :not_found
  end

  test "admin และผู้ที่ยังไม่ login เปิดไม่ได้" do
    settled_scenario
    get results_path_for
    assert_redirected_to login_path
    sign_in(@admin)
    get results_path_for
    assert_response :forbidden
  end

  # ---- รายการผล (USR-17)
  test "USR-17: รายการผลแสดงเฉพาะ event ที่สรุปผลแล้วและผู้ใช้เข้าร่วม พร้อมสรุปผลของตน" do
    settled_scenario
    sign_in(@bua)
    get results_path

    assert_response :success
    assert_select ".ui-card__title", "รอบผล"
    assert_select ".ui-badge--success", "ชนะ 0"
    assert_select ".ui-badge--neutral", "ไม่ชนะ 1"
    assert_select ".ui-badge--muted", "ไม่ขาย 1"
    assert_select "a[href=?]", results_path_for, text: "ดูผล"
  end

  test "รายการผลของผู้ที่ชนะนับชนะ" do
    settled_scenario
    sign_in(@ana)
    get results_path
    assert_select ".ui-badge--success", "ชนะ 1"
  end

  test "รายการผลว่างแสดงข้อความ และไม่แสดง event ที่ยังไม่สรุปผลหรือที่ไม่ได้เข้าร่วม" do
    sign_in(@ana)
    get results_path
    assert_select ".ui-empty-state, .ui-card", /ยังไม่มีผลการประมูล/

    settled_scenario
    delete logout_path
    sign_in(create_approved_bidder(admin: @admin))
    get results_path
    assert_select ".ui-card__title", text: "รอบผล", count: 0
  end

  test "USR-17: เมนูมีลิงก์ 'ผลการประมูล' ให้ผู้ที่ผ่านตรวจ ทุกหน้า ไม่แสดงให้ผู้ที่ยังไม่ผ่านตรวจหรือ admin" do
    sign_in(@ana)
    [ root_path, my_auctions_path, profile_path ].each do |path|
      get path
      assert_select "header a.ui-header__link[href=?]", results_path, text: "ผลการประมูล"
    end

    delete logout_path
    sign_in(@admin)
    get admin_root_path
    assert_select "a[href=?]", results_path, count: 0

    delete logout_path
    waiting = create_bidder
    sign_in(waiting)
    get qualification_path
    assert_select "a[href=?]", results_path, count: 0
  end

  # ---- เชื่อมกับหน้าอื่น
  test "การประมูลของฉัน: event ที่สรุปผลแล้วมีลิงก์ไปผล ส่วนที่ยังไม่สรุปกดไม่ได้" do
    place(@ana, @lot_a, "1800")
    travel_to(@starts_at + 31.seconds) do
      sign_in(@ana)
      get my_auctions_path
      assert_select "button[disabled]", "กำลังสรุปผล"
    end

    settle!
    sign_in(@ana)
    get my_auctions_path
    assert_select "a[href=?]", results_path_for, text: "ดูผลการประมูล"
  end

  test "ห้องประมูลของ event ที่สรุปผลแล้ว: ผู้เข้าร่วมไปหน้าผล ผู้อื่นไปการประมูลของฉัน" do
    settled_scenario
    sign_in(@ana)
    get auction_event_room_path(@event)
    assert_redirected_to results_path_for

    delete logout_path
    sign_in(create_approved_bidder(admin: @admin))
    get auction_event_room_path(@event)
    assert_redirected_to my_auctions_path
  end
end
