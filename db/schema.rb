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

ActiveRecord::Schema[8.1].define(version: 2026_09_16_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assistant_messages", force: :cascade do |t|
    t.string "conversation_key", null: false
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.text "question", null: false
    t.jsonb "reply", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_assistant_messages_on_created_at"
    t.index ["user_id", "conversation_key", "created_at"], name: "index_assistant_conversation"
    t.index ["user_id"], name: "index_assistant_messages_on_user_id"
  end

  create_table "card_candidates", force: :cascade do |t|
    t.string "country", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "name", null: false
    t.jsonb "research", default: {}, null: false
    t.text "review_notes"
    t.string "review_status", default: "pending", null: false
    t.datetime "reviewed_at"
    t.string "reviewed_by"
    t.integer "shortlist_position", null: false
    t.string "source_key", null: false
    t.datetime "updated_at", null: false
    t.index ["country", "review_status"], name: "index_card_candidates_on_country_and_review_status"
    t.index ["source_key"], name: "index_card_candidates_on_source_key", unique: true
    t.check_constraint "country::text = 'US'::text AND currency::text = 'USD'::text OR country::text = 'GB'::text AND currency::text = 'GBP'::text", name: "card_candidates_market"
    t.check_constraint "review_status::text = ANY (ARRAY['pending'::character varying::text, 'reviewed'::character varying::text, 'rejected'::character varying::text])", name: "card_candidates_review_status"
  end

  create_table "cards", force: :cascade do |t|
    t.decimal "annual_fee", precision: 10, scale: 2
    t.text "best_for"
    t.string "card_type"
    t.string "catalogue_status", default: "legacy", null: false
    t.jsonb "catalogue_terms", default: {}, null: false
    t.string "country"
    t.datetime "created_at", null: false
    t.integer "credit_score_min"
    t.string "currency"
    t.text "description"
    t.boolean "foreign_transaction_fee"
    t.string "issuer"
    t.string "name"
    t.string "network"
    t.text "perks"
    t.float "reward_rate"
    t.string "source_key"
    t.datetime "updated_at", null: false
    t.string "welcome_bonus"
    t.index ["catalogue_status"], name: "index_cards_on_catalogue_status"
    t.index ["source_key"], name: "index_cards_on_source_key", unique: true
    t.check_constraint "catalogue_status::text = ANY (ARRAY['legacy'::character varying::text, 'draft'::character varying::text, 'published'::character varying::text, 'retired'::character varying::text])", name: "cards_catalogue_status"
    t.check_constraint "source_key IS NULL OR country::text = 'US'::text AND currency::text = 'USD'::text", name: "cards_real_market"
  end

  create_table "quiz_responses", force: :cascade do |t|
    t.text "answers"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "top_card_ids"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_quiz_responses_on_user_id"
  end

  create_table "stack_cards", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.text "role"
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
    t.text "notes"
    t.string "source_key"
    t.datetime "updated_at", null: false
    t.index ["source_key"], name: "index_stacks_on_source_key", unique: true
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
    t.jsonb "wallet_preferences", default: {}, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "wallet_items", force: :cascade do |t|
    t.date "apply_on"
    t.date "bonus_deadline"
    t.decimal "bonus_spend", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "bonus_target", precision: 12, scale: 2
    t.bigint "card_id", null: false
    t.datetime "created_at", null: false
    t.date "opened_on"
    t.boolean "paid", default: false, null: false
    t.date "payment_due_on"
    t.decimal "statement_balance", precision: 12, scale: 2
    t.string "status", default: "planned", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["card_id"], name: "index_wallet_items_on_card_id"
    t.index ["user_id", "card_id"], name: "index_wallet_items_on_user_id_and_card_id", unique: true
    t.index ["user_id"], name: "index_wallet_items_on_user_id"
  end

  add_foreign_key "assistant_messages", "users", on_delete: :cascade
  add_foreign_key "quiz_responses", "users"
  add_foreign_key "stack_cards", "cards"
  add_foreign_key "stack_cards", "stacks"
  add_foreign_key "wallet_items", "cards"
  add_foreign_key "wallet_items", "users"
end
