require "test_helper"

class StatusHelperTest < ActionView::TestCase
  include UiHelper

  test "สถานะประมูลแมปเป็น label และ tone" do
    assert_equal({ label: "กำลังประมูล", tone: :success }, status_style(:auction, "active"))
    assert_equal :danger, status_style(:auction, :cancelled)[:tone]
  end

  test "สถานะที่ไม่รู้จักเป็น muted ไม่ error" do
    assert_equal({ label: "ไม่ทราบ", tone: :muted }, status_style(:auction, "???"))
    assert_equal({ label: "ไม่ทราบ", tone: :muted }, status_style(:auction, nil))
  end

  test "โดเมนที่ไม่มีต้อง raise" do
    assert_raises(KeyError) { status_style(:nope, "x") }
  end

  test "status_badge ออกเป็น Badge" do
    html = status_badge(:auction, "scheduled")
    assert_includes html, "ui-badge--warning"
    assert_includes html, "รอเริ่ม"
  end

  test "สถานะสินค้าครบทุกค่าของ Item และไม่มีค่าไหนเป็น ไม่ทราบ (ITEM-02)" do
    Item.statuses.each_key do |status|
      assert_not_equal UNKNOWN_STATUS, status_style(:item, status), "ขาด label ของ #{status}"
    end
    assert_equal({ label: "รออนุมัติ", tone: :warning }, status_style(:item, "awaiting_approval"))
    assert_equal "พร้อมขาย", status_style(:item, :available)[:label]
  end
end
