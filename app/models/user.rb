class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :wallet_items, dependent: :destroy
  has_many :cards, through: :wallet_items
  has_many :quiz_responses, dependent: :destroy

  validates :first_name, presence: true
end
