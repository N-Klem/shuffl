class Stack < ApplicationRecord
  has_many :stack_cards, -> { order(:position, :id) }, dependent: :destroy
  has_many :cards, through: :stack_cards

  scope :available, -> {
    where(id: StackCard.select(:stack_id)).where.not(id: StackCard.joins(:card).where.not(cards: { catalogue_status: %w[legacy published] }).select(:stack_id))
  }

  validates :name, presence: true
  validates :category, presence: true

  def annual_fee
    fees = cards.map(&:annual_fee)
    fees.any?(&:nil?) ? nil : fees.sum
  end

  # Editorial roles stay separate from issuer facts in the card catalogue.
  # Stable keys make reseeding safe without replacing historical stacks.
  def self.import_demo!
    definitions = JSON.parse(Rails.root.join("data/real_cards/stacks.json").read)
    transaction do
      definitions.each do |definition|
        members = definition.fetch("cards")
        raise ArgumentError, "Curated stacks need two to five cards" unless members.size.between?(2, 5)

        stack = find_or_initialize_by(source_key: definition.fetch("source_key"))
        stack.update!(definition.slice("name", "category", "description", "notes"))
        card_ids = members.each_with_index.map do |member, position|
          card = Card.available.find_by!(source_key: member.fetch("source_key"))
          stack.stack_cards.find_or_initialize_by(card: card).update!(position: position, role: member.fetch("role"))
          card.id
        end
        stack.stack_cards.where.not(card_id: card_ids).destroy_all
      end
    end
    definitions.size
  end
end
