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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_090200) do
  create_table "assets", force: :cascade do |t|
    t.integer "qualification_submission_id", null: false
    t.string "name", null: false
    t.decimal "value", precision: 15, scale: 2, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["qualification_submission_id"], name: "index_assets_on_qualification_submission_id"
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

  add_foreign_key "assets", "qualification_submissions"
  add_foreign_key "audit_logs", "users", column: "admin_id"
  add_foreign_key "qualification_submissions", "users"
  add_foreign_key "qualification_submissions", "users", column: "reviewed_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "suspension_events", "users"
  add_foreign_key "suspension_events", "users", column: "admin_id"
  add_foreign_key "users", "users", column: "disabled_by_id"
end
