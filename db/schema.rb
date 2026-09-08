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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_140646) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cards", force: :cascade do |t|
    t.integer "annual_fee"
    t.text "best_for"
    t.string "card_type"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "issuer"
    t.string "name"
    t.string "network"
    t.text "perks"
    t.float "reward_rate"
    t.datetime "updated_at", null: false
    t.string "welcome_bonus"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "card_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id"], name: "index_messages_on_card_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "quiz_responses", force: :cascade do |t|
    t.text "answers"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "top_card_ids"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_quiz_responses_on_user_id"
  end

  create_table "stack_cards", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.bigint "stack_id", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_stack_cards_on_card_id"
    t.index ["stack_id", "card_id"], name: "index_stack_cards_on_stack_id_and_card_id", unique: true
    t.index ["stack_id"], name: "index_stack_cards_on_stack_id"
  end

  create_table "stacks", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wallet_items", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id"], name: "index_wallet_items_on_card_id"
    t.index ["user_id", "card_id"], name: "index_wallet_items_on_user_id_and_card_id", unique: true
    t.index ["user_id"], name: "index_wallet_items_on_user_id"
  end

  add_foreign_key "messages", "cards"
  add_foreign_key "messages", "users"
  add_foreign_key "quiz_responses", "users"
  add_foreign_key "stack_cards", "cards"
  add_foreign_key "stack_cards", "stacks"
  add_foreign_key "wallet_items", "cards"
  add_foreign_key "wallet_items", "users"
end
