require "test_helper"

# #80 NFR-21: หน้าห้องรีเฟรชเองเมื่อสถานะเปลี่ยน และมีแบนเนอร์เมื่อการเชื่อมต่อหลุด · ยื่นราคาเป็น POST ปกติ
class RoomRealtimeTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    @admin = create_admin
    item = Item.create!(name: "สินค้าสด", description: "x", starting_price: 1_000, reserve_price: 1_500).tap { |i| i.approve!(by: @admin) }
    @starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @event = AuctionEvent.create!(name: "รอบสด", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: @starts_at, ends_at: @starts_at + 2.hours, selected_item_ids: [ item.id ])
    @user = create_approved_bidder(assets: [ { name: "บ้าน", value: "9000" } ], admin: @admin)
    Participation.create!(user: @user, lot: @event.lots.first)
  end

  test "NFR-21: หน้าห้องสมัครรับการอัปเดตของ event และมีแบนเนอร์ซ่อนไว้" do
    sign_in(@user)
    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      get auction_event_room_path(@event)
    end
    assert_response :success
    assert_select "turbo-cable-stream-source"
    assert_select "[data-controller=connection-status] [data-connection-status-target=banner][hidden]", /เชื่อมต่อใหม่/
  end

  test "NFR-21: event เริ่มและสรุปผลแล้วสั่งหน้าห้องรีเฟรช (ไม่มีข้อมูลราคาในข้อความ)" do
    messages = capture_broadcasts(@event.to_gid_param) do
      travel_to(@starts_at + 1.second) { @event.reload.start! }
      travel_to(@starts_at + 40.seconds) { @event.reload.settle! }
    end
    assert_equal 2, messages.size
    messages.each do |m|
      assert_match(/refresh/, m)
      %w[amount reserve 1500 1,500].each { |w| assert_not_includes m, w }
    end
  end

  test "NFR-21: การยื่นราคาเป็น POST ปกติ ไม่ใช้ช่องทางเรียลไทม์" do
    sign_in(@user)
    travel_to(@starts_at + 5.seconds) do
      @event.reload.start!
      assert_difference -> { Bid.count }, 1 do
        post lot_bid_path(@event.lots.first), params: { bid: { amount: "1800" } }
      end
    end
    assert_response :redirect
  end
end
