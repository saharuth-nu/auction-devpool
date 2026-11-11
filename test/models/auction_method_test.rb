require "test_helper"

class AuctionMethodTest < ActiveSupport::TestCase
  def build(**attrs)
    AuctionMethod.new({ code: "dutch", name: "ประมูลแบบดัตช์", bidding_seconds: 45 }.merge(attrs))
  end

  test "ข้อมูลครบบันทึกได้ และเปิดใช้งานเป็นค่าเริ่มต้น" do
    method = build
    assert method.save
    assert method.enabled?
  end

  test "ต้องมีรหัสและชื่อ" do
    method = build(code: "", name: "")
    assert_not method.valid?
    assert method.errors.of_kind?(:code, :blank)
    assert method.errors.of_kind?(:name, :blank)
  end

  test "รหัสต้องไม่ซ้ำ" do
    method = build(code: "first_price")
    assert_not method.valid?
    assert method.errors.of_kind?(:code, :taken)
  end

  test "รหัสเป็นตัวพิมพ์เล็ก ตัวเลข และขีดล่างเท่านั้น" do
    assert_not build(code: "First Price").valid?
    assert build(code: "sealed_2nd").valid?
  end

  test "ระยะเวลายื่นราคาต้องเป็นจำนวนเต็มบวก (METH-07)" do
    [ nil, 0, -5, 1.5 ].each do |seconds|
      assert_not build(bidding_seconds: seconds).valid?, "#{seconds.inspect} ไม่ควรผ่าน"
    end
  end

  test "ระยะเวลายื่นราคาอ่านเป็น Duration จากค่ากำหนดที่เดียว (METH-07)" do
    assert_equal 30.seconds, auction_methods(:first_price).bidding_duration
  end

  test "ใน M1 มีแค่ first_price ที่ทำงานได้จริง (METH-04)" do
    assert auction_methods(:first_price).implemented?
    assert_not auction_methods(:english).implemented?
  end

  test "เลือกตอนสร้าง event ได้เฉพาะวิธีที่เปิดใช้งานและทำงานได้จริง (METH-04/06)" do
    assert_equal [ auction_methods(:first_price) ], AuctionMethod.selectable.to_a

    auction_methods(:first_price).update!(enabled: false)
    assert_empty AuctionMethod.selectable
  end

  test "เปิด/ปิดใช้งานได้ (METH-03)" do
    method = auction_methods(:first_price)
    method.disable!
    assert_not method.reload.enabled?
    method.enable!
    assert method.reload.enabled?
  end

  test "first_price หาได้จากรหัส" do
    assert_equal auction_methods(:first_price), AuctionMethod.first_price
  end
end
