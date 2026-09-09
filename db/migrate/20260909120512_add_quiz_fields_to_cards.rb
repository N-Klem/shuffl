class AddQuizFieldsToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :credit_score_min, :integer
    add_column :cards, :foreign_transaction_fee, :boolean, default: false, null: false
  end
end
