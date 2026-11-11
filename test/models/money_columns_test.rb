require "test_helper"

# NFR-09: เงินต้องเก็บเป็นจำนวนเต็มหรือ decimal ห้ามใช้ float
# ตรวจทุกคอลัมน์ของทุกตารางใน db/schema.rb จึงครอบ migration ที่ทีมเพิ่มภายหลังโดยอัตโนมัติ
class MoneyColumnsTest < ActiveSupport::TestCase
  FLOAT_TYPES = %i[float].freeze

  # ถ้ามีคอลัมน์ที่ต้องเป็น float จริงๆ และไม่ใช่เงิน (เช่น คะแนน) ให้เพิ่มเป็น "ตาราง.คอลัมน์" พร้อมเหตุผลในคอมเมนต์
  ALLOWED_FLOAT_COLUMNS = [].freeze

  # ชื่อคอลัมน์ที่เป็นเงินต้องเป็น integer หรือ decimal เท่านั้น
  MONEY_NAME = /price|amount|value|fee|cost|reserve|balance|total|bid/i
  MONEY_TYPES = %i[integer bigint decimal].freeze

  test "NFR-09 ไม่มีคอลัมน์ float ในฐานข้อมูล" do
    offenders = columns_of_all_tables.select { |table, column| FLOAT_TYPES.include?(column.type) && !allowed?(table, column) }

    assert_empty offenders.map { |table, column| "#{table}.#{column.name} (#{column.type})" },
                 "ห้ามใช้ float กับเงิน ให้เปลี่ยนเป็น integer (สตางค์) หรือ decimal"
  end

  test "NFR-09 คอลัมน์ที่ชื่อเป็นเงินต้องเป็น integer หรือ decimal" do
    offenders = columns_of_all_tables.select do |table, column|
      column.name.match?(MONEY_NAME) && column.type != :boolean && !column.name.end_with?("_id", "_at") &&
        !MONEY_TYPES.include?(column.type) && !allowed?(table, column)
    end

    assert_empty offenders.map { |table, column| "#{table}.#{column.name} (#{column.type})" },
                 "คอลัมน์ที่ชื่อเกี่ยวกับเงินต้องเป็น integer หรือ decimal (ถ้าไม่ใช่เงินจริง ให้เพิ่มใน ALLOWED_FLOAT_COLUMNS พร้อมเหตุผล)"
  end

  private

  def columns_of_all_tables
    connection = ActiveRecord::Base.connection
    (connection.tables - %w[schema_migrations ar_internal_metadata]).flat_map do |table|
      connection.columns(table).map { |column| [ table, column ] }
    end
  end

  def allowed?(table, column)
    ALLOWED_FLOAT_COLUMNS.include?("#{table}.#{column.name}")
  end
end
