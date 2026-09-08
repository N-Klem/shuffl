class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.string :name
      t.string :issuer
      t.string :network
      t.string :card_type
      t.integer :annual_fee
      t.float :reward_rate
      t.string :welcome_bonus
      t.text :perks
      t.text :best_for
      t.text :description
      t.string :image_url

      t.timestamps
    end
  end
end
