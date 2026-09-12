# Shared catalogue rates keep Wallet and Results estimates consistent.
class WalletDashboard
  def initialize(user)
    @user = user
  end

  def payload
    quiz = @user.quiz_responses.order(created_at: :desc).first || QuizResponse.new(answers: "{}", top_card_ids: "[]")
    source = ResultsStack.new(quiz).payload
    amounts = @user.wallet_preferences["amounts"] || source[:amounts]
    items = @user.wallet_items.includes(:card).order(:created_at).to_a
    records = Card.all.index_by(&:id)
    catalogue = source[:cards].map do |data|
      card = records.fetch(data[:id])
      data.merge(metal: data[:finish], fg: data[:ink], bonus: card.welcome_bonus.presence || "No bonus listed",
        rate: data[:perks].first || data[:role], perk: data[:perks].second || "See card details",
        description: card.description, categories: card.best_for.to_s.split(",").map(&:strip))
    end
    {
      cards: items.map do |item|
        catalogue.find { |card| card[:id] == item.card_id }.merge(
          cardId: item.card_id, id: item.id, owned: item.status == "owned",
          opened: item.opened_on, apply: item.apply_on, deadline: item.bonus_deadline,
          due: item.payment_due_on, balance: item.statement_balance&.to_f,
          spent: item.bonus_spend.to_f, goal: item.bonus_target&.to_f, paid: item.paid)
      end,
      catalogue: catalogue, amounts: amounts, categories: source[:categories],
      notifications: ActiveModel::Type::Boolean.new.cast(@user.wallet_preferences["notifications"]),
      today: Date.current.iso8601
    }
  end
end
