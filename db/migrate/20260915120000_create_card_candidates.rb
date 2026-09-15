class CreateCardCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :card_candidates do |t|
      t.string :source_key, null: false
      t.integer :shortlist_position, null: false
      t.string :name, null: false
      t.string :country, null: false
      t.string :currency, null: false
      t.jsonb :research, default: {}, null: false
      t.string :review_status, default: "pending", null: false
      t.text :review_notes
      t.string :reviewed_by
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :card_candidates, :source_key, unique: true
    add_index :card_candidates, [ :country, :review_status ]
    add_check_constraint :card_candidates, "(country = 'US' AND currency = 'USD') OR (country = 'GB' AND currency = 'GBP')", name: "card_candidates_market"
    add_check_constraint :card_candidates, "review_status IN ('pending', 'reviewed', 'rejected')", name: "card_candidates_review_status"
  end
end
