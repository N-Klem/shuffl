class AddRealCatalogueToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :source_key, :string
    add_index :cards, :source_key, unique: true
    add_column :cards, :country, :string
    add_column :cards, :currency, :string
    add_column :cards, :catalogue_status, :string, default: "legacy", null: false
    add_column :cards, :catalogue_terms, :jsonb, default: {}, null: false
    add_index :cards, :catalogue_status
    change_column :cards, :annual_fee, :decimal, precision: 10, scale: 2
    change_column_null :cards, :foreign_transaction_fee, true
    change_column_default :cards, :foreign_transaction_fee, from: false, to: nil
    add_check_constraint :cards, "catalogue_status IN ('legacy', 'draft', 'published', 'retired')", name: "cards_catalogue_status"
    add_check_constraint :cards, "source_key IS NULL OR (country = 'US' AND currency = 'USD')", name: "cards_real_market"
  end
end
