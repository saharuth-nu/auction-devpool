class AddImageOrderToItems < ActiveRecord::Migration[8.1]
  def change
    # ลำดับรูปสินค้า (ITEM-07): id ของ active_storage_attachments เรียงตามที่ admin จัด
    # รูปที่ไม่อยู่ในรายการ (เพิ่งอัปโหลด) ต่อท้ายตามลำดับอัปโหลด
    add_column :items, :image_order, :json, null: false, default: []
  end
end
