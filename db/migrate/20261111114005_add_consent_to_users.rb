# บันทึกการยินยอมเงื่อนไขการใช้งานและนโยบายความเป็นส่วนตัว (PDPA) ตอนสมัคร (AUTH-19)
# consented_at = เวลาที่ยินยอม (นาฬิกาเซิร์ฟเวอร์) · terms_version = เวอร์ชันของข้อความที่ผู้ใช้เห็นตอนยินยอม
# ว่างได้: บัญชีที่ไม่ได้สมัครผ่านหน้า register (admin, ข้อมูลเดิม) ไม่มีการยินยอมที่บันทึกไว้
class AddConsentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :consented_at, :datetime
    add_column :users, :terms_version, :string
  end
end
