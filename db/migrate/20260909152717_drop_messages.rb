class DropMessages < ActiveRecord::Migration[8.1]
  def change
    drop_table :messages
  end
end
