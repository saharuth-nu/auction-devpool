require "test_helper"

# #55 EVT-07: job เริ่มการประมูลตามเวลา + job กวาดซ้ำ
class StartAuctionEventJobTest < ActiveJob::TestCase
  setup do
    @event = auction_events(:upcoming)
  end

  test "สร้างหรือเลื่อนเวลาเริ่ม ตั้ง job ไว้ที่ starts_at" do
    starts_at = 3.days.from_now.change(usec: 0)
    assert_enqueued_with(job: StartAuctionEventJob, at: starts_at) do
      AuctionEvent.create!(name: "รอบใหม่", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
        starts_at: starts_at, ends_at: starts_at + 1.hour, selected_item_ids: [ items(:car).id ])
    end

    new_start = @event.starts_at + 1.hour
    assert_enqueued_with(job: StartAuctionEventJob, args: [ @event.id ], at: new_start) do
      @event.update!(starts_at: new_start, ends_at: @event.ends_at + 1.hour)
    end
  end

  test "แก้แค่ชื่อไม่ตั้ง job ใหม่" do
    assert_no_enqueued_jobs(only: StartAuctionEventJob) { @event.update!(name: "ชื่อใหม่") }
  end

  test "ถึงเวลาแล้ว job เริ่มการประมูล" do
    travel_to @event.starts_at do
      StartAuctionEventJob.perform_now(@event.id)
    end
    assert @event.reload.bidding?
    assert items(:necklace).reload.in_auction?
  end

  test "job มาก่อนเวลา (หรือเวลาถูกเลื่อน) ไม่เริ่ม และตั้ง job ใหม่ที่ starts_at ปัจจุบัน" do
    travel_to @event.starts_at - 5.seconds do
      assert_enqueued_with(job: StartAuctionEventJob, args: [ @event.id ], at: @event.starts_at) do
        StartAuctionEventJob.perform_now(@event.id)
      end
    end
    assert @event.reload.scheduled?
  end

  test "event ที่ยกเลิก หรือถูกลบไปแล้ว job ไม่ทำอะไร" do
    @event.cancel!
    travel_to @event.starts_at do
      assert_no_enqueued_jobs { StartAuctionEventJob.perform_now(@event.id) }
    end
    assert @event.reload.cancelled?

    assert_nothing_raised { StartAuctionEventJob.perform_now(-1) }
  end

  test "job กวาดซ้ำเริ่มทุก event ที่ถึงเวลาแล้วแต่ยังไม่เริ่ม" do
    later = AuctionEvent.create!(name: "รอบหลัง", room: rooms(:main_hall), auction_method: auction_methods(:first_price),
      starts_at: @event.starts_at + 1.day, ends_at: @event.starts_at + 1.day + 1.hour, selected_item_ids: [ items(:car).id ])

    travel_to @event.starts_at + 2.minutes do
      StartDueAuctionEventsJob.perform_now
    end
    assert @event.reload.bidding?
    assert later.reload.scheduled?, "รอบที่ยังไม่ถึงเวลาต้องไม่เริ่ม"
  end

  test "job กวาดซ้ำตั้งไว้ทุกนาทีใน production" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = config.dig("production", "start_due_auction_events")
    assert_equal "StartDueAuctionEventsJob", task["class"]
    assert_equal "every minute", task["schedule"]
  end
end
