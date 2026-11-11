require "test_helper"

# NFR-19 (#72): ห้ามลบประวัติโดย cascade · ทุก foreign key ใน schema ต้องไม่ cascade/nullify
# ตารางใหม่ (เช่น bids, participations) ถูกตรวจอัตโนมัติจาก test นี้ ไม่ต้องเขียนเพิ่ม
class ForeignKeyPolicyTest < ActiveSupport::TestCase
  FORBIDDEN_ON_DELETE = %i[cascade nullify].freeze

  def connection = ActiveRecord::Base.connection

  def forbidden_foreign_keys
    connection.tables.flat_map { |table| connection.foreign_keys(table) }
      .select { |fk| FORBIDDEN_ON_DELETE.include?(fk.on_delete) }
      .map { |fk| "#{fk.from_table}.#{fk.column} → #{fk.to_table} (on_delete: #{fk.on_delete})" }
  end

  test "ไม่มี foreign key ใดลบตามแถวแม่ (cascade) หรือล้างค่าอ้างอิง (nullify)" do
    assert_empty forbidden_foreign_keys
  end

  test "ตัวตรวจจับ foreign key แบบ cascade ได้จริง" do
    connection.create_table(:fk_policy_probes) { |t| t.references :room, foreign_key: { on_delete: :cascade } }
    assert_includes forbidden_foreign_keys, "fk_policy_probes.room_id → rooms (on_delete: cascade)"
  ensure
    connection.drop_table(:fk_policy_probes, if_exists: true)
  end
end
