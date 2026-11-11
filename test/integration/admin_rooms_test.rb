require "test_helper"

# #45 ROOM-01/02 · ROOM-05 (เก็บถาวร)
class AdminRoomsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in(create_admin)
  end

  def room_params(**overrides)
    { room: { name: "ห้อง B", description: "ห้องเล็ก", max_participants: 20, max_items: 5 }.merge(overrides) }
  end

  test "ROOM-01: รายการห้องแสดงข้อมูลครบ และซ่อนห้องที่เก็บถาวร" do
    get admin_rooms_path
    assert_response :success
    assert_select "tr", text: /ห้องใหญ่/ do
      assert_select "td.num", "50"
      assert_select "td.num", "10"
    end
    assert_select "td", text: "ห้องเก่า", count: 0
  end

  test "ROOM-05: ดูห้องที่เก็บถาวรได้แยกต่างหาก" do
    get admin_rooms_path(archived: 1)
    assert_response :success
    assert_select "td", "ห้องเก่า"
    assert_select "td", text: "ห้องใหญ่", count: 0
  end

  test "ROOM-01/02: เพิ่มห้องพร้อมจำนวนผู้เข้าร่วมและจำนวนสินค้าสูงสุด" do
    get new_admin_room_path
    assert_response :success

    assert_difference -> { Room.count }, 1 do
      post admin_rooms_path, params: room_params
    end
    room = Room.order(:id).last
    assert_redirected_to admin_rooms_path
    assert_equal [ "ห้อง B", "ห้องเล็ก", 20, 5 ], [ room.name, room.description, room.max_participants, room.max_items ]
  end

  test "ROOM-02: ข้อมูลผิดแสดง error และไม่บันทึก" do
    assert_no_difference -> { Room.count } do
      post admin_rooms_path, params: room_params(name: "", max_participants: 0)
    end
    assert_response :unprocessable_entity
    assert_select ".ui-field__error", minimum: 2
  end

  test "ROOM-01: แก้ไขห้องได้" do
    room = rooms(:main_hall)
    get edit_admin_room_path(room)
    assert_response :success

    patch admin_room_path(room), params: room_params(name: "ห้องใหญ่ (ปรับปรุง)", max_items: 12)
    assert_redirected_to admin_rooms_path
    assert_equal "ห้องใหญ่ (ปรับปรุง)", room.reload.name
    assert_equal 12, room.max_items
  end

  test "ROOM-01: แก้ไขด้วยข้อมูลผิดแสดง error" do
    patch admin_room_path(rooms(:main_hall)), params: room_params(max_items: -1)
    assert_response :unprocessable_entity
    assert_equal 10, rooms(:main_hall).reload.max_items
  end

  test "ROOM-01: ลบห้องที่ไม่มีประวัติได้" do
    assert_difference -> { Room.count }, -1 do
      delete admin_room_path(rooms(:main_hall))
    end
    assert_redirected_to admin_rooms_path
  end

  test "ROOM-05: เก็บถาวรห้องได้" do
    room = rooms(:main_hall)
    patch archive_admin_room_path(room)
    assert_redirected_to admin_rooms_path
    assert room.reload.archived?
  end

  test "ผู้ใช้ทั่วไปเข้าหน้าและแก้ห้องไม่ได้ (NFR-08)" do
    delete logout_path
    sign_in(create_bidder)
    room = rooms(:main_hall)

    get admin_rooms_path
    assert_response :forbidden
    post admin_rooms_path, params: room_params
    assert_response :forbidden
    patch admin_room_path(room), params: room_params(name: "แฮก")
    assert_response :forbidden
    delete admin_room_path(room)
    assert_response :forbidden
    assert_equal "ห้องใหญ่", room.reload.name
  end
end
