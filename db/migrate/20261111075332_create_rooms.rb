class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name, null: false
      t.text :description
      t.integer :max_participants, null: false
      t.integer :max_items, null: false
      t.datetime :archived_at

      t.timestamps
      t.check_constraint "max_participants > 0", name: "rooms_max_participants_positive"
      t.check_constraint "max_items > 0", name: "rooms_max_items_positive"
    end
    add_index :rooms, :archived_at
  end
end
