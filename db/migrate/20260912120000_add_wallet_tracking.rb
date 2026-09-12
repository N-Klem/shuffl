class AddWalletTracking < ActiveRecord::Migration[8.1]
  def change
    change_table :wallet_items do |t|
      t.string :status, null: false, default: "planned"
      t.date :opened_on
      t.date :apply_on
      t.date :payment_due_on
      t.date :bonus_deadline
      t.decimal :statement_balance, precision: 12, scale: 2
      t.decimal :bonus_spend, precision: 12, scale: 2, default: 0, null: false
      t.decimal :bonus_target, precision: 12, scale: 2
      t.boolean :paid, default: false, null: false
    end
    add_column :users, :wallet_preferences, :jsonb, default: {}, null: false
  end
end
