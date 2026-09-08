class CreateQuizResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_responses do |t|
      t.references :user, null: false, foreign_key: true
      t.text :answers
      t.text :top_card_ids
      t.datetime :completed_at

      t.timestamps
    end
  end
end
