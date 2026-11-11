require "test_helper"

# requirements: QUAL-02, QUAL-03, QUAL-03a, NFR-09 · task #34
class AssetTest < ActiveSupport::TestCase
  def asset(**attrs)
    Asset.new({ name: "บ้านเดี่ยว", value: "1000" }.merge(attrs)).tap(&:validate)
  end

  test "QUAL-03a: ชื่อต้องกรอก ไม่เกิน 100 ตัวอักษร (รองรับภาษาไทย)" do
    assert asset(name: "  ").errors.include?(:name)
    assert asset(name: "ก" * 101).errors.include?(:name)
    assert_not asset(name: "ก" * 100).errors.include?(:name)
    assert_equal "บ้าน", asset(name: "  บ้าน ").name
  end

  test "QUAL-03a: มูลค่าต้องมากกว่า 0" do
    [ "0", "-1", "0.00", 0, -10 ].each do |bad|
      assert asset(value: bad).errors.include?(:value), "#{bad.inspect} ควรไม่ผ่าน"
    end
    assert_not asset(value: "0.01").errors.include?(:value)
  end

  test "QUAL-03a: ทศนิยมไม่เกิน 2 ตำแหน่ง (ไม่ปัดให้เงียบๆ)" do
    assert asset(value: "10.123").errors.include?(:value)
    assert asset(value: 10.125).errors.include?(:value)
    assert_not asset(value: "10.12").errors.include?(:value)
    assert_not asset(value: "10.5").errors.include?(:value)
  end

  test "QUAL-03a: ไม่ใช่ตัวเลขหรือว่างไม่ผ่าน" do
    [ "", nil, "abc", "12a", "1e5", "๑๐๐" ].each do |bad|
      assert asset(value: bad).errors.include?(:value), "#{bad.inspect} ควรไม่ผ่าน"
    end
  end

  test "QUAL-03a: ไม่เกิน 1,000,000,000,000 บาทต่อรายการ" do
    assert_not asset(value: "1000000000000").errors.include?(:value)
    assert asset(value: "1000000000000.01").errors.include?(:value)
  end

  test "รับค่าที่คั่นหลักพันและเก็บเป็น decimal (NFR-09)" do
    a = asset(value: "1,250,000.75")
    assert_not a.errors.include?(:value)
    assert_kind_of BigDecimal, a.value
    assert_equal BigDecimal("1250000.75"), a.value
  end
end
