class QuizResponse < ApplicationRecord
  belongs_to :user

  validates :answers, presence: true
  validates :completed_at, presence: true
end
