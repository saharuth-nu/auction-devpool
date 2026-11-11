class CreateAuctionMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :auction_methods do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :bidding_seconds, null: false
      t.boolean :enabled, null: false, default: true

      t.timestamps
      t.check_constraint "bidding_seconds > 0", name: "auction_methods_bidding_seconds_positive"
    end
    add_index :auction_methods, :code, unique: true
  end
end
