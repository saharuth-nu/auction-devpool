require "test_helper"

# #66 BID-06, BID-14, NFR-06: job สรุปผลตามเวลา + job กวาดซ้ำ
class SettleAuctionEventJobTest < ActiveJob::TestCase
  setup do
    @admin = create_admin
    starts_at = Time.zone.now.change(usec: 0) + 1.hour
    @item = Item.create!(name: "สินค้า", description: "x", starting_price: 1_000, reserve_price: 1_500).tap { |i| i.approve!(by: @admin) }
    @event = AuctionEvent.create!(name: "รอบ", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
                                  starts_at: starts_at, ends_at: starts_at + 2.hours, selected_item_ids: [ @item.id ])
    @lot = @event.lots.sole
    @user = create_approved_bidder(admin: @admin)
    Participation.create!(user: @user, lot: @lot)
    @deadline = @event.starts_at + 30.seconds
  end

  def start_event
    travel_to(@event.starts_at) { @event.reload.start! }
  end

  test "เริ่มรับราคาแล้ว ตั้ง job สรุปผลไว้หลังเวลาปิดรับราคา" do
    assert_enqueued_with(job: SettleAuctionEventJob, args: [ @event.id ], at: @deadline + AuctionEvent::SETTLEMENT_DELAY) do
      start_event
    end
  end

  test "แก้ event ที่ยังไม่เริ่มหรือที่เริ่มไปแล้ว ไม่ตั้ง job สรุปผลซ้ำ" do
    assert_no_enqueued_jobs(only: SettleAuctionEventJob) { @event.update!(name: "ชื่อใหม่") }
    start_event
    clear_enqueued_jobs
    assert_no_enqueued_jobs(only: SettleAuctionEventJob) { @event.reload.update!(name: "ชื่อใหม่อีกที") }
  end

  test "เลยเวลาปิดรับราคาแล้ว job สรุปผล" do
    start_event
    travel_to(@event.starts_at + 5.seconds) { PlaceBid.call(user: @user, lot: @lot, amount: 1_800) }

    travel_to(@deadline + 1.second) { SettleAuctionEventJob.perform_now(@event.id) }

    assert @event.reload.settled?
    assert @lot.reload.sold?
  end

  test "job มาก่อนเวลาปิดรับราคา ไม่สรุป และตั้ง job ใหม่ไว้หลังเส้นตาย" do
    start_event
    travel_to(@deadline - 5.seconds) do
      assert_enqueued_with(job: SettleAuctionEventJob, args: [ @event.id ], at: @deadline + AuctionEvent::SETTLEMENT_DELAY) do
        SettleAuctionEventJob.perform_now(@event.id)
      end
    end
    assert @event.reload.bidding?
  end

  test "event ที่สรุปแล้วหรือยังไม่เริ่ม job ไม่ทำอะไร" do
    travel_to(@deadline + 1.minute) { SettleAuctionEventJob.perform_now(@event.id) }
    assert @event.reload.scheduled?

    start_event
    travel_to(@deadline + 1.minute) do
      SettleAuctionEventJob.perform_now(@event.id)
      SettleAuctionEventJob.perform_now(@event.id)
    end
    assert @event.reload.settled?
  end

  test "event ที่ถูกลบไปแล้ว job ทิ้งเงียบๆ (ไม่ error)" do
    assert_nothing_raised { SettleAuctionEventJob.perform_now(0) }
  end

  test "NFR-06: job กวาดซ้ำสรุปผล event ที่เลยเวลาแล้วแต่ job ตั้งเวลาหลุด" do
    start_event

    travel_to(@deadline) { SettleDueAuctionEventsJob.perform_now } # ที่เส้นตายพอดียังไม่เลย
    assert @event.reload.bidding?

    travel_to(@deadline + 1.second) { SettleDueAuctionEventsJob.perform_now }
    assert @event.reload.settled?
  end

  test "job กวาดซ้ำรันซ้ำได้ผลเดิม" do
    start_event
    travel_to(@deadline + 1.second) do
      SettleDueAuctionEventsJob.perform_now
      before = @event.reload.attributes
      SettleDueAuctionEventsJob.perform_now
      assert_equal before, @event.reload.attributes
    end
  end

  test "ตั้งให้ job กวาดซ้ำรันทุกนาทีใน production (config/recurring.yml)" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    entry = config.fetch("production").fetch("settle_due_auction_events")
    assert_equal "SettleDueAuctionEventsJob", entry["class"]
    assert_equal "every minute", entry["schedule"]
  end
end
