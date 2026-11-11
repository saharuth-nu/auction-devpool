require "test_helper"

# USR-16: การประมูลของฉัน แยก ยังไม่เริ่ม / กำลังประมูล / จบแล้ว ตามเวลาของเซิร์ฟเวอร์ (NFR-03)
class MyAuctionsTest < ActiveSupport::TestCase
  setup do
    @user = create_approved_bidder
    @base = Time.zone.now.change(usec: 0)
  end

  # event ในอนาคต (เริ่มอีก hours ชั่วโมง) + 1 lot ผู้ใช้เข้าร่วมแล้ว · ตรวจโดยเลื่อนเวลาไปข้างหน้า
  def build_joined_event(hours:, user: @user)
    room = Room.create!(name: "ห้อง #{SecureRandom.hex(3)}", max_participants: 10, max_items: 5)
    starts = (@base + hours.hours)
    event = AuctionEvent.create!(name: "รอบ #{hours} ชม.", room:, auction_method: auction_methods(:first_price),
                                 starts_at: starts, ends_at: starts + 1.hour)
    lot = Lot.create!(auction_event: event, item: Item.create!(description: "รายละเอียด", name: "ของ #{hours}", starting_price: 100, reserve_price: 100, status: :available))
    Participation.create!(user:, lot:)
    [ event, lot ]
  end

  def names(groups) = groups.map { |group| group.event.name }

  test "USR-16 แยกเป็นยังไม่เริ่ม กำลังประมูล และจบแล้ว ตามเวลาปัจจุบัน" do
    build_joined_event(hours: 1) # จบแล้ว (เลยเวลารับราคา)
    build_joined_event(hours: 2) # กำลังประมูล
    build_joined_event(hours: 3) # ยังไม่เริ่ม
    travel_to(@base + 2.hours + 5.seconds) do
      auctions = MyAuctions.for(@user)
      assert_equal [ "รอบ 3 ชม." ], names(auctions.upcoming)
      assert_equal [ "รอบ 2 ชม." ], names(auctions.live)
      assert_equal [ "รอบ 1 ชม." ], names(auctions.finished)
    end
  end

  test "NFR-03 ขอบเวลา: ถึงเวลาเริ่มพอดี = กำลังประมูล ครบเวลารับราคาพอดียังกำลังประมูล เกินไปแม้ 1 วินาที = จบแล้ว" do
    event, = build_joined_event(hours: 1)
    travel_to(event.starts_at - 1.second) { assert_equal 1, MyAuctions.for(@user).upcoming.size }
    travel_to(event.starts_at) { assert_equal 1, MyAuctions.for(@user).live.size }
    travel_to(event.bidding_ends_at) { assert_equal 1, MyAuctions.for(@user).live.size }
    travel_to(event.bidding_ends_at + 1.second) { assert_equal 1, MyAuctions.for(@user).finished.size }
  end

  test "event ที่สรุปผลหรือยกเลิกแล้วเป็นจบแล้ว แม้เวลายังไม่ถึง" do
    settled, = build_joined_event(hours: 5)
    cancelled, = build_joined_event(hours: 6)
    settled.update_columns(status: "settled")
    cancelled.update_columns(status: "cancelled")
    auctions = MyAuctions.for(@user)
    assert_equal [ "รอบ 6 ชม.", "รอบ 5 ชม." ], names(auctions.finished) # จบแล้วเรียงล่าสุดก่อน
    assert_empty auctions.upcoming
  end

  test "เรียงยังไม่เริ่มและกำลังประมูลตามเวลาเริ่ม ใกล้ถึงก่อน" do
    build_joined_event(hours: 9)
    build_joined_event(hours: 4)
    build_joined_event(hours: 7)
    assert_equal [ "รอบ 4 ชม.", "รอบ 7 ชม.", "รอบ 9 ชม." ], names(MyAuctions.for(@user).upcoming)
  end

  test "การเข้าร่วมที่ผู้ใช้ยกเลิกเองและของผู้ใช้อื่นไม่แสดง" do
    _event, lot = build_joined_event(hours: 3)
    other = create_approved_bidder
    build_joined_event(hours: 4, user: other)
    Participation.find_by!(user: @user, lot:).cancel!
    assert MyAuctions.for(@user).empty?
    assert_equal [ "รอบ 4 ชม." ], names(MyAuctions.for(other).upcoming)
  end

  test "lot ที่ถูกนำออกจาก event ยังแสดงเป็นประวัติ (NFR-19)" do
    _event, lot = build_joined_event(hours: 3)
    lot.update!(status: :cancelled)
    group = MyAuctions.for(@user).upcoming.first
    assert_equal [ lot.id ], group.participations.map { |p| p.lot.id }
  end

  test "event เดียวกันหลายสินค้า รวมเป็นกลุ่มเดียว" do
    event, lot_a = build_joined_event(hours: 3)
    lot_b = Lot.create!(auction_event: event, item: Item.create!(description: "รายละเอียด", name: "อีกชิ้น", starting_price: 100, reserve_price: 100, status: :available))
    Participation.create!(user: @user, lot: lot_b)
    group = MyAuctions.for(@user).upcoming.sole
    assert_equal [ lot_a.id, lot_b.id ].sort, group.participations.map { |p| p.lot.id }.sort
  end

  test "ไม่เข้าร่วมอะไรเลย empty? เป็นจริง" do
    assert MyAuctions.for(create_approved_bidder).empty?
  end

  test "ดึงข้อมูลชุดเดียว ไม่เกิด N+1 เมื่อมีหลาย event" do
    5.times { |i| build_joined_event(hours: 10 + i) }
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      MyAuctions.for(@user).upcoming.each do |group|
        group.event.room.name
        group.event.bidding_ends_at
        group.participations.each { |p| p.lot.item.images.attachments.to_a }
      end
    end
    assert_operator queries, :<=, 8, "query มากเกินไป (#{queries}) น่าจะมี N+1"
  end
end
