class AddUniqueIndexToWalletItems < ActiveRecord::Migration[8.1]
  def change
    add_index :wallet_items, [:user_id, :card_id], unique: true
  end
end
