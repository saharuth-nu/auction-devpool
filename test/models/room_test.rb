require "test_helper"

class RoomTest < ActiveSupport::TestCase
  def build(**attrs)
    Room.new({ name: "ห้อง A", max_participants: 20, max_items: 5 }.merge(attrs))
  end

  test "ข้อมูลครบบันทึกได้ รายละเอียดไม่บังคับ (ROOM-02)" do
    assert build(description: nil).save
  end

  test "ต้องมีชื่อห้อง" do
    room = build(name: " ")
    assert_not room.valid?
    assert room.errors.of_kind?(:name, :blank)
  end

  test "จำนวนผู้เข้าร่วมและจำนวนสินค้าสูงสุดต้องเป็นจำนวนเต็มบวก (ROOM-02)" do
    [ nil, 0, -1, 2.5 ].each do |value|
      assert_not build(max_participants: value).valid?, "max_participants #{value.inspect}"
      assert_not build(max_items: value).valid?, "max_items #{value.inspect}"
    end
  end

  test "เก็บถาวรแล้วหายจากรายการปกติ แต่ยังหาเจอด้วย id (ROOM-05)" do
    room = rooms(:main_hall)
    room.archive!

    assert room.archived?
    assert_not_includes Room.active, room
    assert_equal room, Room.find(room.id)
  end

  test "รายการปกติไม่รวมห้องที่เก็บถาวรแล้ว" do
    assert_equal [ rooms(:main_hall) ], Room.active.to_a
  end
end
