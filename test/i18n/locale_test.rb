require "test_helper"

# NFR-01 (ภาษาไทย), NFR-02 (เขตเวลา Asia/Bangkok)
class LocaleTest < ActiveSupport::TestCase
  # key ของ Rails ที่ผู้ใช้อาจเห็น ต้องมีคำไทยครบเทียบกับ en
  # (ข้าม number.nth: เป็น Proc ของภาษาอังกฤษ ไม่ใช้ในระบบนี้)
  NAMESPACES = %w[errors.messages errors.format activerecord.errors date time datetime helpers number support].freeze
  SKIPPED = [ "number.nth" ].freeze

  test "NFR-01 locale เริ่มต้นเป็นไทย" do
    assert_equal :th, I18n.default_locale
    assert_equal :th, I18n.locale
  end

  test "NFR-02 เขตเวลาเป็น Asia/Bangkok และ DB เก็บเป็น UTC" do
    assert_equal "Bangkok", Time.zone.name
    assert_equal "Asia/Bangkok", Time.zone.tzinfo.name
    assert_equal :utc, ActiveRecord.default_timezone
  end

  test "NFR-02 เวลาที่เก็บเป็น UTC แสดงเป็นเวลาไทย (+7)" do
    assert_equal 7.hours, Time.zone.utc_offset
    assert_equal 20, Time.utc(2026, 11, 13, 13, 0, 0).in_time_zone.hour
  end

  test "NFR-01 กลไกแจ้งข้อความที่ยังไม่มี translation เปิดอยู่ (กันข้อความหลุดเป็นอังกฤษ)" do
    assert Rails.application.config.i18n.raise_on_missing_translations
  end

  test "NFR-01 th มีทุก key ที่ Rails ใช้ใน en" do
    missing = leaf_keys(:en) - leaf_keys(:th)
    assert_empty missing, "th.yml ยังขาด key เหล่านี้ (เพิ่มใน config/locales/th.yml):\n  #{missing.join("\n  ")}"
  end

  test "NFR-01 ข้อความ validation ที่ Rails สร้างเป็นไทย" do
    sample = Class.new do
      include ActiveModel::Model

      attr_accessor :name, :age

      def self.model_name = ActiveModel::Name.new(self, nil, "Sample")

      validates :name, presence: true, length: { maximum: 5 }
      validates :age, numericality: { greater_than: 0 }
    end

    record = sample.new(name: "", age: "abc")
    assert_not record.valid?
    assert_equal [ "ต้องกรอก" ], record.errors[:name]
    assert_equal [ "ต้องเป็นตัวเลข" ], record.errors[:age]

    record = sample.new(name: "ยาวเกินห้าตัว", age: 0)
    assert_not record.valid?
    assert_equal [ "ยาวเกินไป (ไม่เกิน 5 ตัวอักษร)" ], record.errors[:name]
    assert_equal [ "ต้องมากกว่า 0" ], record.errors[:age]
  end

  test "NFR-01 ข้อความของ Rails ที่เหลือเป็นไทย" do
    assert_equal "13 พฤศจิกายน 2026", I18n.l(Date.new(2026, 11, 13), format: :long)
    assert_equal "ครึ่งนาที", I18n.t("datetime.distance_in_words.half_a_minute")
    assert_equal "ก, ข และ ค", [ "ก", "ข", "ค" ].to_sentence
    assert_equal "ก และ ข", [ "ก", "ข" ].to_sentence
  end

  private

  # key ปลายทางทั้งหมดของ locale ใน namespace ที่สนใจ (ไม่รวมค่า)
  def leaf_keys(locale)
    I18n.t("date.day_names", locale: :th) # สั่งให้ backend โหลดไฟล์แปลก่อน
    tree = I18n.backend.send(:translations)[locale] || {}
    flatten_keys(tree)
      .select { |key| NAMESPACES.any? { |ns| key == ns || key.start_with?("#{ns}.") } }
      .reject { |key| SKIPPED.any? { |skip| key == skip || key.start_with?("#{skip}.") } }
      .sort
  end

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, path) : [ path ]
    end
  end
end
