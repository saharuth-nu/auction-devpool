# Audit log ของการกระทำของ admin (task #71 · NFR-17, NFR-18, NFR-19)
# เพิ่มได้อย่างเดียว: ไม่มี updated_at และ model ปฏิเสธการแก้/ลบ
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.references :target, polymorphic: true
      t.json :change_set, null: false, default: {}
      t.text :reason
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
