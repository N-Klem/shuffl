class CreateStackCards < ActiveRecord::Migration[8.1]
  def change
    create_table :stack_cards do |t|
      t.references :stack, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true

      t.timestamps
    end

    add_index :stack_cards, [ :stack_id, :card_id ], unique: true
  end
end
