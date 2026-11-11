require "test_helper"

# #54 EVT-01–08, EVT-11: หน้าจัดการการประมูลของ admin
class AdminAuctionEventsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_admin
    sign_in(@admin)
  end

  def valid_params(**overrides)
    starts_at = 2.days.from_now.change(sec: 0)
    { auction_event: {
      name: "ประมูลรอบใหม่",
      room_id: rooms(:main_hall).id,
      auction_method_id: auction_methods(:first_price).id,
      starts_at: starts_at.strftime("%Y-%m-%dT%H:%M"),
      ends_at: (starts_at + 2.hours).strftime("%Y-%m-%dT%H:%M"),
      selected_item_ids: [ items(:car).id ]
    }.merge(overrides) }
  end

  # ---- สิทธิ์ (AUTH-10, NFR-08)
  test "ผู้ใช้ทั่วไปเข้าหน้าจัดการการประมูลไม่ได้" do
    delete logout_path
    sign_in(create_bidder)
    get admin_auction_events_path
    assert_response :forbidden
  end

  # ---- รายการ (EVT-01)
  test "EVT-01: รายการแสดงทุก event พร้อมสถานะ และปุ่มสร้างใหม่" do
    get admin_auction_events_path
    assert_response :success
    assert_select "a[href=?]", new_admin_auction_event_path, text: "สร้างการประมูลใหม่"
    assert_select "tbody tr", AuctionEvent.count
    assert_select ".ui-badge", "ยังไม่เริ่ม"
    assert_select ".ui-badge", "เปิดรับราคา"
    assert_select ".ui-badge", "สรุปผลแล้ว"
  end

  test "EVT-08: แก้ไข/ยกเลิก/ลบ มีเฉพาะ event ที่ยังไม่เริ่ม และยกเลิก/ลบต้องยืนยันก่อน" do
    get admin_auction_events_path
    upcoming = auction_events(:upcoming)
    assert_select "a[href=?]", edit_admin_auction_event_path(upcoming)
    assert_select "form[action=?] button[data-turbo-confirm]", cancel_admin_auction_event_path(upcoming)
    assert_select "form[action=?] button[data-turbo-confirm]", admin_auction_event_path(upcoming)

    [ auction_events(:live), auction_events(:finished) ].each do |event|
      assert_select "a[href=?]", edit_admin_auction_event_path(event), count: 0
      assert_select "form[action=?]", cancel_admin_auction_event_path(event), count: 0
    end
  end

  # ---- สร้าง (EVT-02/03/04/05)
  test "EVT-02: สร้าง event พร้อมสินค้าได้" do
    get new_admin_auction_event_path
    assert_response :success
    assert_select "input[type=checkbox][value=?]", items(:car).id.to_s
    assert_select "input[type=checkbox][value=?]", items(:painting).id.to_s, count: 0 # อยู่ใน event อื่น (EVT-04)

    assert_difference -> { AuctionEvent.count } => 1, -> { Lot.count } => 1 do
      post admin_auction_events_path, params: valid_params
    end
    assert_redirected_to admin_auction_events_path
    event = AuctionEvent.order(:id).last
    assert event.scheduled?
    assert_equal [ items(:car) ], event.items.to_a
  end

  test "ไม่เลือกสินค้าเลย แจ้ง error ใต้ช่องสินค้า" do
    params = valid_params
    params[:auction_event].delete(:selected_item_ids)
    assert_no_difference -> { AuctionEvent.count } do
      post admin_auction_events_path, params: params
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /อย่างน้อย 1 ชิ้น/
  end

  test "EVT-03: ใส่สินค้าเกินที่ห้องรองรับไม่ได้" do
    room = Room.create!(name: "ห้องจิ๋ว", max_participants: 5, max_items: 1)
    extra = Item.create!(name: "ชิ้นที่สอง", starting_price: 100, reserve_price: 100, status: :available)
    assert_no_difference -> { AuctionEvent.count } do
      post admin_auction_events_path, params: valid_params(room_id: room.id, selected_item_ids: [ items(:car).id, extra.id ])
    end
    assert_select ".ui-field__error", /ไม่เกิน 1 ชิ้น/
  end

  test "EVT-04: สินค้าที่อยู่ใน event อื่นที่ยังไม่จบใส่ไม่ได้ แม้ส่ง request ตรงๆ" do
    assert_no_difference -> { Lot.count } do
      post admin_auction_events_path, params: valid_params(selected_item_ids: [ items(:painting).id ])
    end
    assert_response :unprocessable_entity
  end

  test "EVT-05: เวลาสิ้นสุดเร็วกว่าเวลาเริ่ม + 30 วินาทีไม่ได้" do
    starts_at = 2.days.from_now.change(sec: 0)
    post admin_auction_events_path,
      params: valid_params(starts_at: starts_at.strftime("%Y-%m-%dT%H:%M"), ends_at: starts_at.strftime("%Y-%m-%dT%H:%M"))
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", /30 วินาที/
  end

  # ---- แก้ไข (EVT-01/08)
  test "แก้ event ที่ยังไม่เริ่มได้ รวมถึงเปลี่ยนสินค้า" do
    event = auction_events(:upcoming)
    get edit_admin_auction_event_path(event)
    assert_response :success
    assert_select "input[type=checkbox][value=?][checked]", items(:necklace).id.to_s

    patch admin_auction_event_path(event), params: { auction_event: { name: "ชื่อใหม่", selected_item_ids: [ items(:car).id ] } }
    assert_redirected_to admin_auction_events_path
    assert_equal "ชื่อใหม่", event.reload.name
    assert_equal [ items(:car) ], event.items.to_a
  end

  test "EVT-08: event ที่เริ่มแล้ว ฟอร์มปิดช่องเวลา/ห้อง/สินค้า แก้ได้เฉพาะชื่อ" do
    event = auction_events(:live)
    get edit_admin_auction_event_path(event)
    assert_select "select[name=?][disabled]", "auction_event[room_id]"
    assert_select "input[name=?][disabled]", "auction_event[starts_at]"
    assert_select "input[type=checkbox]", count: 0

    patch admin_auction_event_path(event), params: { auction_event: { name: "ชื่อใหม่" } }
    assert_redirected_to admin_auction_events_path
    assert_equal "ชื่อใหม่", event.reload.name
    assert_equal [ items(:painting) ], event.items.to_a
  end

  test "EVT-08: ส่ง request แก้เวลาของ event ที่เริ่มแล้วตรงๆ ถูกปฏิเสธ" do
    event = auction_events(:live)
    original = event.ends_at
    patch admin_auction_event_path(event), params: { auction_event: { ends_at: 5.hours.from_now.strftime("%Y-%m-%dT%H:%M") } }
    assert_response :unprocessable_entity
    assert_equal original.to_i, event.reload.ends_at.to_i
  end

  # ---- ยกเลิก (EVT-08)
  test "EVT-08: ยกเลิก event ที่ยังไม่เริ่มได้ สินค้าถูกปล่อย" do
    event = auction_events(:upcoming)
    patch cancel_admin_auction_event_path(event)
    assert_redirected_to admin_auction_events_path
    assert event.reload.cancelled?
    assert lots(:upcoming_necklace).reload.cancelled?
  end

  test "EVT-08: ยกเลิก event ที่เริ่มแล้วไม่ได้" do
    patch cancel_admin_auction_event_path(auction_events(:live))
    assert_redirected_to admin_auction_events_path
    follow_redirect!
    assert_select ".ui-alert--error", /ยังไม่เริ่ม/
    assert auction_events(:live).reload.bidding?
  end

  # ---- ลบ (EVT-08/11, NFR-19)
  test "ลบ event ที่ยังไม่เริ่มได้" do
    assert_difference -> { AuctionEvent.count } => -1, -> { Lot.count } => -1 do
      delete admin_auction_event_path(auction_events(:upcoming))
    end
    assert_redirected_to admin_auction_events_path
  end

  test "EVT-11/NFR-19: ลบ event ที่เริ่มหรือจบแล้วด้วย request ตรงๆ ไม่ได้" do
    assert_no_difference -> { AuctionEvent.count } do
      delete admin_auction_event_path(auction_events(:finished))
    end
    follow_redirect!
    assert_select ".ui-alert--error", /ยังไม่เริ่ม/
  end
end
