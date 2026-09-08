class Message < ApplicationRecord
  belongs_to :user
  belongs_to :card, optional: true

  validates :content, presence: true
  validates :role, inclusion: { in: %w[user assistant] }
end
