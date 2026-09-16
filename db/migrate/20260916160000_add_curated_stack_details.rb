class AddCuratedStackDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :stacks, :source_key, :string
    add_index :stacks, :source_key, unique: true
    add_column :stacks, :notes, :text
    add_column :stack_cards, :position, :integer, default: 0, null: false
    add_column :stack_cards, :role, :text
  end
end
