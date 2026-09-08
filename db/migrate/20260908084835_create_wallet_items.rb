class CreateWalletItems < ActiveRecord::Migration[8.1]
  def change
    create_table :wallet_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true

      t.timestamps
    end
  end
end
