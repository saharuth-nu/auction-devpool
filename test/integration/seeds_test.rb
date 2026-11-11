require "test_helper"

# #28 AUTH-09: seed admin คนแรก
class SeedsTest < ActiveSupport::TestCase
  def run_seeds(env = {})
    keys = %w[ADMIN_USERNAME ADMIN_PASSWORD]
    before = keys.index_with { |k| ENV[k] }
    keys.each { |k| ENV.delete(k) }
    env.each { |k, v| ENV[k] = v }
    load Rails.root.join("db/seeds.rb")
  ensure
    before.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "AUTH-09: seed สร้าง admin คนแรกจาก ENV" do
    assert_difference -> { User.admin.count }, 1 do
      run_seeds("ADMIN_USERNAME" => "firstadmin", "ADMIN_PASSWORD" => "S3cretPassw0rd")
    end
    admin = User.find_by!(username: "firstadmin")
    assert admin.admin?
    assert admin.authenticate("S3cretPassw0rd")
    assert_nil admin.email
    assert_not admin.must_change_password?
  end

  test "ไม่ตั้ง ENV (dev/test): ใช้ username admin และสุ่มรหัสผ่านที่ผ่านกฎ" do
    run_seeds
    admin = User.find_by!(username: "admin")
    assert admin.admin?
    assert_not admin.authenticate("password")
  end

  test "รันซ้ำไม่สร้างเพิ่มและไม่เปลี่ยนรหัสผ่านของ admin เดิม" do
    run_seeds("ADMIN_USERNAME" => "firstadmin", "ADMIN_PASSWORD" => "S3cretPassw0rd")
    assert_no_difference -> { User.count } do
      run_seeds("ADMIN_USERNAME" => "another", "ADMIN_PASSWORD" => "DifferentPassw0rd")
    end
    assert User.find_by!(username: "firstadmin").authenticate("S3cretPassw0rd")
    assert_nil User.find_by(username: "another")
  end

  test "มี admin อยู่แล้ว (สร้างจากที่อื่น) seed ไม่สร้างซ้ำ" do
    create_admin
    assert_no_difference -> { User.count } do
      run_seeds("ADMIN_PASSWORD" => "S3cretPassw0rd")
    end
  end

  test "production ต้องตั้ง ADMIN_PASSWORD เอง (ไม่มีรหัสเริ่มต้นใน repo)" do
    original = Rails.env
    begin
      Rails.env = ActiveSupport::EnvironmentInquirer.new("production")
      error = assert_raises(RuntimeError) { run_seeds }
      assert_match(/ADMIN_PASSWORD/, error.message)
    ensure
      Rails.env = original
    end
    assert_equal 0, User.admin.count
  end

  test "ADMIN_PASSWORD ที่อ่อนเกินถูกปฏิเสธโดยกฎของโมเดล" do
    assert_raises(ActiveRecord::RecordInvalid) { run_seeds("ADMIN_PASSWORD" => "short") }
  end
end
