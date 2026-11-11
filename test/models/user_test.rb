require "test_helper"

# requirements: AUTH-04, AUTH-05, AUTH-06, AUTH-08, AUTH-15 (requirements/01-accounts.md)
class UserTest < ActiveSupport::TestCase
  def bidder(**attrs)
    User.new({ username: "somchai", email: "somchai@example.com", fullname: "สมชาย ใจดี",
               password: "password123", password_confirmation: "password123" }.merge(attrs))
  end

  def admin(**attrs)
    User.new({ username: "admin01", role: :admin, password: "password123", password_confirmation: "password123" }.merge(attrs))
  end

  # ---- role (AUTH-08)
  test "AUTH-08: role เริ่มต้นเป็น bidder และมีเฉพาะ admin/bidder" do
    assert bidder.bidder?
    assert admin.admin?
    assert_equal %w[admin bidder], User.roles.keys.sort
    assert_raises(ArgumentError) { User.new(role: "superadmin") }
  end

  test "bidder ที่ถูกต้องบันทึกได้" do
    assert bidder.save
  end

  # ---- username (AUTH-04)
  test "AUTH-04: username เก็บเป็นตัวพิมพ์เล็กและตัดช่องว่าง" do
    user = bidder(username: "  SomChai_01 ")
    assert user.save
    assert_equal "somchai_01", user.reload.username
  end

  test "AUTH-04: username ซ้ำไม่สนตัวพิมพ์ใหญ่/เล็ก" do
    assert bidder(username: "Somchai").save
    other = bidder(username: "somchai", email: "other@example.com")
    assert_not other.valid?
    assert other.errors.of_kind?(:username, :taken)
  end

  test "AUTH-04: username ซ้ำข้ามบทบาท admin กับ bidder" do
    assert admin(username: "shared01").save
    assert_not bidder(username: "SHARED01").valid?
  end

  test "AUTH-04: รูปแบบ username ต้องเป็น a-z 0-9 _ ยาว 4-30" do
    %w[abc a_b ab!cd ab\ cd สมชายใจดี somchai-x].each do |bad|
      assert_not bidder(username: bad).valid?, "#{bad.inspect} ควรไม่ผ่าน"
    end
    assert_not bidder(username: "a" * 31).valid?
    assert bidder(username: "abcd").valid?
    assert bidder(username: "a" * 30).valid?
    assert bidder(username: "user_123").valid?
  end

  test "AUTH-04: username ว่างไม่ผ่าน" do
    assert_not bidder(username: "").valid?
    assert_not bidder(username: nil).valid?
  end

  # ---- email (AUTH-05)
  test "AUTH-05: email ต้องมีรูปแบบถูกต้อง" do
    %w[plainaddress @no-local.com no-at.example.com a@b@c.com].each do |bad|
      assert_not bidder(email: bad).valid?, "#{bad.inspect} ควรไม่ผ่าน"
    end
  end

  test "AUTH-05: email ยาวไม่เกิน 254 ตัวอักษร" do
    long = "#{'a' * 64}@#{'b' * 63}.#{'c' * 63}.#{'d' * 63}.com" # 64+1+63+1+63+1+63+4 = 260
    assert_operator long.length, :>, 254
    assert_not bidder(email: long).valid?
  end

  test "AUTH-05: email เก็บเป็นตัวพิมพ์เล็กและซ้ำไม่สนตัวพิมพ์" do
    assert bidder(email: "Somchai@Example.COM").save
    assert_equal "somchai@example.com", User.find_by!(username: "somchai").email
    other = bidder(username: "another", email: "SOMCHAI@example.com")
    assert_not other.valid?
    assert other.errors.of_kind?(:email, :taken)
  end

  test "AUTH-05: bidder ต้องมี email" do
    assert_not bidder(email: nil).valid?
    assert_not bidder(email: "").valid?
  end

  test "ADM-04: admin ไม่ต้องมี email/fullname และมี admin หลายคนที่ email เป็น NULL ได้" do
    assert admin(username: "admin01").save
    assert admin(username: "admin02").save
  end

  # ---- fullname (AUTH-15)
  test "AUTH-15: bidder ต้องมี fullname ไม่เกิน 100 ตัวอักษร รองรับภาษาไทย" do
    assert_not bidder(fullname: "").valid?
    assert_not bidder(fullname: nil).valid?
    assert_not bidder(fullname: "ก" * 101).valid?
    assert bidder(fullname: "ก" * 100).valid?
    assert bidder(fullname: "นางสาวสมหญิง รักเรียน").valid?
  end

  # ---- password (AUTH-06)
  test "AUTH-06: password ต้องยาวอย่างน้อย 8 ตัวอักษร" do
    assert_not bidder(password: "short12", password_confirmation: "short12").valid?
    assert bidder(password: "eight888", password_confirmation: "eight888").valid?
  end

  test "AUTH-06: password ไม่เกิน 72 ไบต์ (ขีดจำกัด bcrypt)" do
    ok = "a" * 72
    too_long = "a" * 73
    assert bidder(password: ok, password_confirmation: ok).valid?
    assert_not bidder(password: too_long, password_confirmation: too_long).valid?
  end

  test "AUTH-06: นับเป็นไบต์ ตัวอักษรไทย 1 ตัว = 3 ไบต์ จึงเกิน 72 ที่ 25 ตัว" do
    thai24 = "ก" * 24 # 72 ไบต์ พอดี
    thai25 = "ก" * 25 # 75 ไบต์
    assert bidder(password: thai24, password_confirmation: thai24).valid?
    user = bidder(password: thai25, password_confirmation: thai25)
    assert_not user.valid?
    assert user.errors[:password].any?
  end

  test "AUTH-06: ช่องยืนยัน password ต้องกรอกและตรงกัน" do
    assert_not bidder(password_confirmation: "different123").valid?
    assert_not bidder(password_confirmation: "").valid?
    assert_not bidder(password_confirmation: nil).valid?
  end

  test "password เก็บเป็น hash ไม่ใช่ plain text และตรวจรหัสผ่านได้" do
    user = bidder
    user.save!
    assert_not_equal "password123", user.password_digest
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong-password")
  end

  test "แก้ข้อมูลอื่นโดยไม่ต้องส่ง password ใหม่" do
    user = bidder
    user.save!
    user = User.find(user.id)
    assert user.update(fullname: "ชื่อใหม่")
  end

  # ---- DB constraints (NFR-05 แนวคิดเดียวกัน: บังคับที่ระดับฐานข้อมูลด้วย)
  test "unique index ที่ DB กัน username ซ้ำแม้ข้าม validation" do
    assert bidder.save
    dup = bidder(email: "dup@example.com")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save(validate: false) }
  end

  test "unique index ที่ DB กัน email ซ้ำแม้ข้าม validation" do
    assert bidder.save
    dup = bidder(username: "another01")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save(validate: false) }
  end
end
