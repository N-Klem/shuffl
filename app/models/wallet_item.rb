class WalletItem < ApplicationRecord
  belongs_to :user
  belongs_to :card

  validates :status, inclusion: { in: %w[owned planned] }
  validates :statement_balance, :bonus_spend, :bonus_target,
            numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }, allow_nil: true
  validate :bonus_dates_in_order

  def bonus_dates_in_order
    if opened_on && bonus_deadline && bonus_deadline < opened_on
      errors.add(:bonus_deadline, "must be on or after the opening date")
    end
  end

  validates :card_id, uniqueness: { scope: :user_id }
end
