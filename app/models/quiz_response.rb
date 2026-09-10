class QuizResponse < ApplicationRecord
  belongs_to :user, optional: true

  validates :answers, presence: true
  validates :completed_at, presence: true
end
