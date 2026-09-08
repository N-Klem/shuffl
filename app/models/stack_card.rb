class StackCard < ApplicationRecord
  belongs_to :stack
  belongs_to :card

  validates :card_id, uniqueness: { scope: :stack_id }
end
