require "test_helper"

# NFR-03: การตัดสินเวลาใช้เวลาของเซิร์ฟเวอร์ผ่าน Clock เท่านั้น
class ClockTest < ActiveSupport::TestCase
  setup do
    # event เริ่ม 13 พ.ย. 2026 20:00 น. (เวลาไทย) วิธีประมูลให้เวลา 30 วินาที (BID-02)
    @starts_at = Time.zone.local(2026, 11, 13, 20, 0, 0)
    @closes_at = @starts_at + 30.seconds
  end

  test "NFR-03 Clock.now คือเวลาของเซิร์ฟเวอร์ ตามเขตเวลา Asia/Bangkok" do
    travel_to Time.utc(2026, 11, 13, 13, 0, 0) do
      assert_equal Time.utc(2026, 11, 13, 13, 0, 0), Clock.now
      assert_equal "Asia/Bangkok", Clock.now.time_zone.tzinfo.name
      assert_equal 20, Clock.now.hour
    end
  end

  test "NFR-03 Clock.now เดินตามเวลาจริงเมื่อไม่ได้แช่ไว้" do
    before = Time.current
    now = Clock.now
    assert_operator now, :>=, before
    assert_operator now, :<=, Time.current
  end

  test "reached? ถึงเวลาแล้วนับรวมวินาทีที่เท่ากันพอดี" do
    travel_to @starts_at - 1.second do
      assert_not Clock.reached?(@starts_at)
    end
    travel_to @starts_at do
      assert Clock.reached?(@starts_at)
    end
    travel_to @starts_at + 1.second do
      assert Clock.reached?(@starts_at)
    end
  end

  test "passed? เลยเวลาไปแล้วเมื่อเท่ากันพอดียังไม่เลย" do
    travel_to @closes_at do
      assert_not Clock.passed?(@closes_at)
    end
    travel_to @closes_at + 1.second do
      assert Clock.passed?(@closes_at)
    end
  end

  test "BID-02 within? ยื่นราคาได้ตั้งแต่เริ่มจนครบ 30 วินาทีพอดี นับทั้งต้นและปลายช่วง" do
    travel_to @starts_at - 0.001.seconds, with_usec: true do
      assert_not Clock.within?(@starts_at, @closes_at), "ก่อนเริ่มยื่นไม่ได้"
    end
    travel_to @starts_at do
      assert Clock.within?(@starts_at, @closes_at), "วินาทีเริ่มพอดียื่นได้"
    end
    travel_to @starts_at + 15.seconds do
      assert Clock.within?(@starts_at, @closes_at)
    end
    travel_to @closes_at do
      assert Clock.within?(@starts_at, @closes_at), "ครบ 30 วินาทีพอดียังยื่นทัน"
    end
    travel_to @closes_at + 0.001.seconds, with_usec: true do
      assert_not Clock.within?(@starts_at, @closes_at), "เกิน 30 วินาทีแม้ 1 มิลลิวินาทียื่นไม่ได้"
    end
  end

  test "remaining เหลือกี่วินาที และไม่ติดลบเมื่อเลยเวลา" do
    travel_to @starts_at do
      assert_in_delta 30.0, Clock.remaining(@closes_at), 0.0001
    end
    travel_to @starts_at + 12.5.seconds, with_usec: true do
      assert_in_delta 17.5, Clock.remaining(@closes_at), 0.0001
    end
    travel_to @closes_at + 10.seconds do
      assert_equal 0.0, Clock.remaining(@closes_at)
    end
  end

  test "เวลาที่เป็น nil raise ทันที ไม่ตีความเงียบๆ" do
    assert_raises(ArgumentError) { Clock.reached?(nil) }
    assert_raises(ArgumentError) { Clock.passed?(nil) }
    assert_raises(ArgumentError) { Clock.within?(nil, @closes_at) }
    assert_raises(ArgumentError) { Clock.within?(@starts_at, nil) }
    assert_raises(ArgumentError) { Clock.remaining(nil) }
  end

  test "Clock ไม่รับเวลาจากภายนอก: ไม่มี method ที่รับเวลา 'ปัจจุบัน' เป็น argument" do
    assert_raises(ArgumentError) { Clock.now(Time.utc(2000, 1, 1)) }
  end
end
