require "test_helper"

class ThaiDateHelperTest < ActionView::TestCase
  test "วันที่เป็นเดือนย่อภาษาไทยและปี พ.ศ." do
    assert_equal "15 พ.ย. 2569", thai_date(Date.new(2026, 11, 15))
    assert_equal "1 ม.ค. 2570", thai_date(Date.new(2027, 1, 1))
    assert_equal "", thai_date(nil)
  end

  test "ช่วงเวลา HH:MM–HH:MM น." do
    starts_at = Time.zone.local(2026, 11, 15, 9, 5)
    assert_equal "09:05–12:00 น.", thai_time_range(starts_at, starts_at.change(hour: 12, min: 0))
  end
end
