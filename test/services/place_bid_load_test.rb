require "test_helper"

# #75 NFR-16: วัดความเร็วการยื่นราคาจำนวนมากบน SQLite (ผลและข้อสรุป O-3/O-4 อยู่ใน docs/load-test.md)
# ข้อสอบนี้ยืนยันว่า 150 คนยื่นราคาภายในหน้าต่าง 30 วินาทีได้ถูกต้องและเร็วพอ (ลำดับ เขียนทีละรายการตามที่ SQLite บังคับ)
class PlaceBidLoadTest < ActiveSupport::TestCase
  BIDDERS = 150
  BUDGET_SECONDS = 15 # เผื่อเครื่อง CI ช้า (วัดจริงในเครื่องพัฒนาอยู่ที่ราว 1–2 วินาที)

  test "NFR-16: #{BIDDERS} คนยื่นราคาในหน้าต่างเดียว ครบทุกรายการ ผู้ชนะถูกต้อง และไม่เกินงบเวลา" do
    admin = create_admin
    item = Item.create!(name: "สินค้าโหลด", description: "x", starting_price: 1_000, reserve_price: 1_000).tap { |i| i.approve!(by: admin) }
    starts_at = Time.zone.now.change(usec: 0) + 1.hour
    event = AuctionEvent.create!(name: "รอบโหลด", room: Room.create!(name: "ห้องโหลด", max_participants: 500, max_items: 5),
                                 auction_method: auction_methods(:first_price), starts_at: starts_at,
                                 ends_at: starts_at + 2.hours, selected_item_ids: [ item.id ])
    lot = event.lots.first
    users = Array.new(BIDDERS) { create_approved_bidder(assets: [ { name: "บ้าน", value: "1000000" } ], admin: admin) }
    users.each { |u| Participation.create!(user: u, lot: lot) }

    elapsed = nil
    travel_to(starts_at + 5.seconds) do
      event.reload.start!
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      users.each_with_index { |u, i| assert PlaceBid.call(user: u, lot: lot, amount: 2_000 + i).bid, "ยื่นไม่สำเร็จ: #{u.username}" }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    assert_equal BIDDERS, lot.bids.count
    travel_to(starts_at + 40.seconds) { event.reload.settle! }
    assert_equal users.last, lot.reload.winning_bid.user
    assert_operator elapsed, :<, BUDGET_SECONDS, "ยื่นราคา #{BIDDERS} รายการใช้ #{elapsed.round(2)} วินาที"
    puts "\n[NFR-16] #{BIDDERS} bids in #{elapsed.round(3)}s (#{(BIDDERS / elapsed).round} bids/s)" if ENV["VERBOSE_LOAD"]
  end
end
