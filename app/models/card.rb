class Card < ApplicationRecord
  has_many :wallet_items, dependent: :destroy
  has_many :users, through: :wallet_items
  has_many :messages, dependent: :nullify

  validates :name, :issuer, :network, :card_type, presence: true
  validates :annual_fee,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reward_rate,
            numericality: { greater_than_or_equal_to: 0 }
end
