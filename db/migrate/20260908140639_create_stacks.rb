class CreateStacks < ActiveRecord::Migration[8.1]
  def change
    create_table :stacks do |t|
      t.string :name
      t.text :description
      t.string :category

      t.timestamps
    end
  end
end
