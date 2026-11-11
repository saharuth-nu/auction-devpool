class CreateAuctionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :auction_events do |t|
      t.string :name, null: false
      # FK แบบ restrict: ลบห้อง/วิธีประมูลที่มี event อ้างถึงไม่ได้ (NFR-19)
      t.references :room, null: false, foreign_key: { on_delete: :restrict }
      t.references :auction_method, null: false, foreign_key: { on_delete: :restrict }
      t.datetime :starts_at, null: false
      # เวลาปิดห้อง ไม่ใช่เวลาปิดรับราคา (EVT-06)
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: "scheduled"
      t.datetime :cancelled_at
      t.datetime :settled_at

      t.timestamps
      t.check_constraint "ends_at > starts_at", name: "auction_events_ends_after_start"
      t.check_constraint "status IN ('scheduled', 'bidding', 'settled', 'cancelled')",
        name: "auction_events_status_valid"
    end
    add_index :auction_events, :status
    add_index :auction_events, :starts_at
  end
end
