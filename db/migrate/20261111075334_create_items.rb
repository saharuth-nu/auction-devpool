class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :name, null: false
      t.text :description
      # เงินเป็น decimal บาท 2 ตำแหน่ง ห้ามใช้ float (NFR-09)
      t.decimal :starting_price, precision: 15, scale: 2, null: false
      t.decimal :reserve_price, precision: 15, scale: 2, null: false
      t.string :status, null: false, default: "awaiting_approval"
      t.datetime :approved_at
      t.datetime :archived_at

      t.timestamps
      t.check_constraint "starting_price > 0", name: "items_starting_price_positive"
      t.check_constraint "reserve_price >= starting_price", name: "items_reserve_not_below_starting"
      t.check_constraint "status IN ('awaiting_approval', 'available', 'in_auction', 'sold')",
        name: "items_status_valid"
    end
    add_index :items, :status
    add_index :items, :archived_at
  end
end
