class CreateAssistantMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_messages do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :conversation_key, null: false
      t.text :question, null: false
      t.jsonb :reply, default: {}, null: false
      t.string :status, default: "pending", null: false
      t.integer :input_tokens, default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.timestamps
    end
    add_index :assistant_messages, :created_at
    add_index :assistant_messages, [ :user_id, :conversation_key, :created_at ], name: "index_assistant_conversation"
  end
end
