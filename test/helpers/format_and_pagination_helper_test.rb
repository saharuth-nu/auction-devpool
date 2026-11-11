require "test_helper"

# helper ที่เพิ่มใน tasks #34–#41/#71: รูปแบบเงิน/เวลา, ui_pagination, ui_select, สถานะโดเมนใหม่
class FormatAndPaginationHelperTest < ActionView::TestCase
  include FormatHelper
  include UiHelper
  include StatusHelper

  test "baht: คั่นหลักพัน มีทศนิยมเมื่อจำเป็น และ nil เป็นขีด" do
    assert_equal "1,500,000 บาท", baht(BigDecimal("1500000"))
    assert_equal "1,500,000.50 บาท", baht(BigDecimal("1500000.5"))
    assert_equal "0 บาท", baht(0)
    assert_equal "-", baht(nil)
  end

  test "plain_amount: ค่าในช่องกรอกไม่มี .0 ต่อท้าย และคงข้อความที่พิมพ์ไว้" do
    assert_equal "100", plain_amount(BigDecimal("100"))
    assert_equal "10.5", plain_amount(BigDecimal("10.50"))
    assert_equal "abc", plain_amount("abc")
    assert_nil plain_amount(nil)
  end

  test "display_time: วัน/เดือน/ปี ชั่วโมง:นาที และ nil เป็นขีด" do
    assert_equal "05/03/2026 09:07", display_time(Time.zone.local(2026, 3, 5, 9, 7))
    assert_equal "-", display_time(nil)
  end

  test "ui_pagination: หน้าเดียวไม่แสดงอะไร" do
    assert_equal "", ui_pagination(Paginated::Page.new(number: 1, per: 25, total_count: 3))
  end

  test "ui_pagination: แสดงหน้าปัจจุบันและลิงก์ก่อนหน้า/ถัดไปที่คงค่า query" do
    controller.request.path = "/admin/users"
    controller.request.query_parameters.merge!("q" => "som")
    html = ui_pagination(Paginated::Page.new(number: 2, per: 10, total_count: 35))
    assert_includes html, "หน้า 2 จาก 4"
    assert_match(/rel="prev"[^>]*|href="[^"]*page=1/, html)
    assert_includes html, "q=som"
    assert_includes html, "ถัดไป"
    assert_includes html, "ก่อนหน้า"
  end

  test "ui_select: มี label, class ui-input และคงค่าที่เลือก" do
    html = ui_form_with(url: "/x", method: :get) do |f|
      f.ui_select :status, [ [ "ผ่าน", "approved" ], [ "ไม่ผ่าน", "rejected" ] ],
                  label: "สถานะ", include_blank: "ทั้งหมด", selected: "rejected"
    end
    assert_includes html, "<label class=\"ui-field__label\" for=\"status\">สถานะ</label>"
    assert_match(/<select[^>]*class="ui-input"/, html)
    assert_match(/<option selected="selected" value="rejected">/, html)
    assert_includes html, ">ทั้งหมด</option>"
  end

  test "status_badge: สถานะคุณสมบัติ รอบส่งตรวจ และการระงับ ใช้ tone ตามความหมาย" do
    assert_equal({ label: "รอ admin ตรวจ", tone: :warning }, status_style(:qualification, "awaiting_review"))
    assert_equal({ label: "ผ่าน", tone: :success }, status_style(:qualification, "approved"))
    assert_equal({ label: "ไม่ผ่าน", tone: :danger }, status_style(:submission, "rejected"))
    assert_equal({ label: "ถูกระงับ", tone: :danger }, status_style(:suspension, "suspended"))
    assert_equal StatusHelper::UNKNOWN_STATUS, status_style(:qualification, nil)
    # สถานะคุณสมบัติใน helper ตรงกับ enum จริง
    assert_equal User.qualification_statuses.keys.sort, StatusHelper::STATUSES[:qualification].keys.sort
  end
end
