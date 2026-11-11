# สถานะบัญชีที่งานสาย A ต้องใช้ (requirements/01-accounts.md)
# - must_change_password: AUTH-13 บังคับเปลี่ยนรหัสผ่านหลัง admin รีเซ็ต
# - suspended_at: SUSP-02 ผู้ถูกระงับ login ไม่ได้ (UI ระงับ/ยกเลิกระงับ + เหตุผล/ประวัติ เป็นของ task #38)
# - disabled_*: ADM-05/08 ปิดใช้งานบัญชี admin (ห้ามลบ ADM-06) เก็บเหตุผลและผู้ปิด
class AddAccountStateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :must_change_password, :boolean, null: false, default: false
    add_column :users, :suspended_at, :datetime
    add_column :users, :disabled_at, :datetime
    add_column :users, :disabled_reason, :text
    add_reference :users, :disabled_by, foreign_key: { to_table: :users }
  end
end
