require "test_helper"

# requirements: ADM-01 (requirements/01-accounts.md) · task #41
class UserDirectoryTest < ActiveSupport::TestCase
  setup do
    @admin = create_admin(username: "admin_main")
    @somchai = create_bidder(username: "somchai", fullname: "สมชาย ใจดี")
    @somsri = create_approved_bidder(username: "somsri_k", fullname: "สมศรี รักงาน", admin: @admin)
    @john = create_bidder(username: "johnny", fullname: "John Smith", email: "john@corp.example")
    @john.suspend!(by: @admin, reason: "ทดสอบ")
  end

  test "ADM-01: แสดงเฉพาะผู้ใช้ (bidder) ไม่รวม admin" do
    assert_equal [ @john, @somsri, @somchai ].map(&:id).sort, User.directory.map(&:id).sort
  end

  test "ADM-01: ค้นหาบางส่วนของ username / fullname / email ไม่สนตัวพิมพ์" do
    assert_equal [ @somchai, @somsri ].map(&:id).sort, User.directory(q: "SOM").map(&:id).sort
    assert_equal [ @somsri ], User.directory(q: "รักงาน").to_a
    assert_equal [ @john ], User.directory(q: "corp.EXAMPLE").to_a
    assert_equal [ @john ], User.directory(q: "smith").to_a
  end

  test "ADM-01: ค้นหาด้วย % หรือ _ ไม่ถูกตีความเป็น wildcard" do
    assert_empty User.directory(q: "%").to_a
    assert_equal [ @somsri ], User.directory(q: "i_k").to_a
  end

  test "ADM-01: กรองตามสถานะคุณสมบัติและสถานะระงับ" do
    assert_equal [ @somsri ], User.directory(qualification_status: "approved").to_a
    assert_equal [ @john, @somchai ].map(&:id).sort,
                 User.directory(qualification_status: "awaiting_assets").map(&:id).sort
    assert_equal [ @john ], User.directory(suspension: "suspended").to_a
    assert_equal [ @somsri, @somchai ].map(&:id).sort, User.directory(suspension: "active").map(&:id).sort
    assert_equal [ @john ], User.directory(q: "john", suspension: "suspended",
                                           qualification_status: "awaiting_assets").to_a
  end

  test "ADM-01: ค่าตัวกรองที่ไม่รู้จักถูกละเว้น" do
    assert_equal 3, User.directory(qualification_status: "hacked", suspension: "maybe").count
  end
end
