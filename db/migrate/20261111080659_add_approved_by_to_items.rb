class AddApprovedByToItems < ActiveRecord::Migration[8.1]
  def change
    # FK แบบ restrict (ค่าเริ่มต้น) ลบ admin ที่เคยอนุมัติสินค้าไม่ได้ (NFR-19)
    add_reference :items, :approved_by, foreign_key: { to_table: :users }
  end
end
