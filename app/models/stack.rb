class Stack < ApplicationRecord
  has_many :stack_cards, dependent: :destroy
  has_many :cards, through: :stack_cards

  validates :name, presence: true
  validates :category, presence: true
end
