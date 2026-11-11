# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_100001) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.integer "qualification_submission_id", null: false
    t.string "name", null: false
    t.decimal "value", precision: 15, scale: 2, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["qualification_submission_id"], name: "index_assets_on_qualification_submission_id"
  end

  create_table "auction_events", force: :cascade do |t|
    t.string "name", null: false
    t.integer "room_id", null: false
    t.integer "auction_method_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "cancelled_at"
    t.datetime "settled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_method_id"], name: "index_auction_events_on_auction_method_id"
    t.index ["room_id"], name: "index_auction_events_on_room_id"
    t.index ["starts_at"], name: "index_auction_events_on_starts_at"
    t.index ["status"], name: "index_auction_events_on_status"
    t.check_constraint "ends_at > starts_at", name: "auction_events_ends_after_start"
    t.check_constraint "status IN ('scheduled', 'bidding', 'settled', 'cancelled')", name: "auction_events_status_valid"
  end

  create_table "auction_methods", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.integer "bidding_seconds", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_auction_methods_on_code", unique: true
    t.check_constraint "bidding_seconds > 0", name: "auction_methods_bidding_seconds_positive"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.integer "admin_id", null: false
    t.string "action", null: false
    t.string "target_type"
    t.integer "target_id"
    t.json "change_set", default: {}, null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["admin_id"], name: "index_audit_logs_on_admin_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["target_type", "target_id"], name: "index_audit_logs_on_target"
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.decimal "starting_price", precision: 15, scale: 2, null: false
    t.decimal "reserve_price", precision: 15, scale: 2, null: false
    t.string "status", default: "awaiting_approval", null: false
    t.datetime "approved_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "approved_by_id"
    t.index ["approved_by_id"], name: "index_items_on_approved_by_id"
    t.index ["archived_at"], name: "index_items_on_archived_at"
    t.index ["status"], name: "index_items_on_status"
    t.check_constraint "reserve_price >= starting_price", name: "items_reserve_not_below_starting"
    t.check_constraint "starting_price > 0", name: "items_starting_price_positive"
    t.check_constraint "status IN ('awaiting_approval', 'available', 'in_auction', 'sold')", name: "items_status_valid"
  end

  create_table "lots", force: :cascade do |t|
    t.integer "auction_event_id", null: false
    t.integer "item_id", null: false
    t.string "status", default: "pending", null: false
    t.decimal "winning_price", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["auction_event_id", "item_id"], name: "index_lots_on_auction_event_id_and_item_id", unique: true
    t.index ["auction_event_id"], name: "index_lots_on_auction_event_id"
    t.index ["item_id"], name: "index_lots_on_item_id"
    t.index ["item_id"], name: "index_lots_one_pending_per_item", unique: true, where: "status = 'pending'"
    t.check_constraint "status <> 'sold' OR winning_price IS NOT NULL", name: "lots_sold_has_winning_price"
    t.check_constraint "status IN ('pending', 'sold', 'unsold', 'cancelled')", name: "lots_status_valid"
    t.check_constraint "winning_price IS NULL OR winning_price > 0", name: "lots_winning_price_positive"
  end

  create_table "qualification_submissions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "submitted_at", null: false
    t.integer "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reviewed_by_id"], name: "index_qualification_submissions_on_reviewed_by_id"
    t.index ["status"], name: "index_qualification_submissions_on_status"
    t.index ["user_id", "submitted_at"], name: "index_qualification_submissions_on_user_id_and_submitted_at"
    t.index ["user_id"], name: "index_qualification_submissions_on_user_id"
    t.index ["user_id"], name: "index_qualification_submissions_one_pending_per_user", unique: true, where: "status = 'pending'"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "max_participants", null: false
    t.integer "max_items", null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_rooms_on_archived_at"
    t.check_constraint "max_items > 0", name: "rooms_max_items_positive"
    t.check_constraint "max_participants > 0", name: "rooms_max_participants_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "suspension_events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "admin_id", null: false
    t.string "action", null: false
    t.text "reason", null: false
    t.datetime "created_at", null: false
    t.index ["admin_id"], name: "index_suspension_events_on_admin_id"
    t.index ["user_id", "created_at"], name: "index_suspension_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_suspension_events_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "email"
    t.string "fullname"
    t.string "role", default: "bidder", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "must_change_password", default: false, null: false
    t.datetime "suspended_at"
    t.datetime "disabled_at"
    t.text "disabled_reason"
    t.integer "disabled_by_id"
    t.string "qualification_status"
    t.index ["disabled_by_id"], name: "index_users_on_disabled_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["qualification_status"], name: "index_users_on_qualification_status"
    t.index ["suspended_at"], name: "index_users_on_suspended_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets", "qualification_submissions"
  add_foreign_key "auction_events", "auction_methods", on_delete: :restrict
  add_foreign_key "auction_events", "rooms", on_delete: :restrict
  add_foreign_key "audit_logs", "users", column: "admin_id"
  add_foreign_key "items", "users", column: "approved_by_id"
  add_foreign_key "lots", "auction_events", on_delete: :restrict
  add_foreign_key "lots", "items", on_delete: :restrict
  add_foreign_key "qualification_submissions", "users"
  add_foreign_key "qualification_submissions", "users", column: "reviewed_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "suspension_events", "users"
  add_foreign_key "suspension_events", "users", column: "admin_id"
  add_foreign_key "users", "users", column: "disabled_by_id"
end
