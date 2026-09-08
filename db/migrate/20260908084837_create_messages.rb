class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: true, foreign_key: true
      t.text :content
      t.string :role

      t.timestamps
    end
  end
end
