require "test_helper"

# db/seeds/90_development_samples.rb: ข้อมูลตัวอย่างสำหรับลองระบบ (development เท่านั้น)
class DevelopmentSeedsTest < ActiveSupport::TestCase
  def run_seeds_as(env_name)
    original = Rails.env
    previous = ENV["ADMIN_PASSWORD"]
    ENV["ADMIN_PASSWORD"] = "S3cretPassw0rd"
    Rails.env = ActiveSupport::EnvironmentInquirer.new(env_name)
    capture_io { load Rails.root.join("db/seeds.rb") }
  ensure
    Rails.env = original
    previous.nil? ? ENV.delete("ADMIN_PASSWORD") : ENV["ADMIN_PASSWORD"] = previous
  end

  def clean_slate
    [ Lot, AuctionEvent, Item, Room, AuctionMethod ].each(&:delete_all)
  end

  setup { clean_slate }

  test "ไม่รันนอก development: ไม่สร้างผู้ประมูล ห้อง สินค้า หรือ event" do
    run_seeds_as("test")

    assert_equal 0, User.bidder.count
    assert_equal 0, Room.count
    assert_equal 0, Item.count
    assert_equal 0, AuctionEvent.count
  end

  test "development: สร้างข้อมูลตัวอย่างครบและผู้ประมูลมีสถานะคุณสมบัติตามที่ระบุ" do
    run_seeds_as("development")

    statuses = User.bidder.pluck(:username, :qualification_status).to_h
    assert_equal(
      { "somchai" => "approved", "somying" => "approved", "waiting" => "awaiting_review",
        "newbie" => "awaiting_assets", "rejected1" => "rejected" },
      statuses
    )
    assert_equal BigDecimal("5000000"), User.find_by!(username: "somchai").bid_ceiling
    assert_equal BigDecimal("1000000"), User.find_by!(username: "somying").bid_ceiling
    assert_equal "มูลค่าทรัพย์สินน้อยเกินไป กรุณาตรวจสอบและส่งใหม่", User.find_by!(username: "rejected1").latest_rejection_reason

    assert_equal 2, Room.count
    assert_equal 8, Item.count
    assert_equal 7, Item.available.count
    assert_equal 1, Item.awaiting_approval.count
    assert_equal 2, AuctionEvent.count
    assert_equal 5, Lot.count
    assert AuctionEvent.all.all?(&:scheduled?), "event ตัวอย่างต้องยังไม่เริ่ม"
    assert(AuctionEvent.all.all? { |e| e.starts_at > Time.current })
  end

  test "ผู้ประมูลตัวอย่างล็อกอินได้ด้วยรหัสผ่านตัวอย่าง และการตรวจผ่านลง audit log" do
    run_seeds_as("development")

    assert User.authenticate_by(username: "somchai", password: "password123")
    assert_equal 2, AuditLog.where(action: "qualification.approve").count
    assert_equal 1, AuditLog.where(action: "qualification.reject").count
  end

  test "รันซ้ำได้ผลเดิม ไม่สร้างซ้ำและไม่เปลี่ยนรหัสผ่าน" do
    run_seeds_as("development")
    counts = [ User.count, Room.count, Item.count, AuctionEvent.count, Lot.count,
               QualificationSubmission.count, AuditLog.count ]
    digest = User.find_by!(username: "somchai").password_digest

    run_seeds_as("development")

    assert_equal counts, [ User.count, Room.count, Item.count, AuctionEvent.count, Lot.count,
                           QualificationSubmission.count, AuditLog.count ]
    assert_equal digest, User.find_by!(username: "somchai").password_digest
  end

  test "ตัวอย่างหน้าแรกของผู้ใช้เห็นเฉพาะสินค้าใน event ที่ยังไม่เริ่ม และไม่เห็นสินค้ารออนุมัติ" do
    run_seeds_as("development")

    entries = AuctionListing.entries.map { |e| e.item.name }
    assert_equal 5, entries.size
    assert_not_includes entries, "ชุดเครื่องแก้วคริสตัล"
    assert_not_includes entries, "รถจักรยานยนต์คลาสสิก" # พร้อมขายแต่ยังไม่อยู่ใน event
  end
end
