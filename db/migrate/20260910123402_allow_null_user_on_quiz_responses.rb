class AllowNullUserOnQuizResponses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :quiz_responses, :user_id, true
  end
end
