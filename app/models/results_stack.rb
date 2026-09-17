require "json"

# Uses live records; historical recommendations retain their original IDs.
class ResultsStack
  def initialize(quiz_response)
    @quiz_response = quiz_response
  end

  def payload
    answers = JSON.parse(@quiz_response.answers.presence || "{}")
    ids = JSON.parse(@quiz_response.top_card_ids.presence || "[]")
    selected = ids.filter_map { |id| Card.find_by(id: id) }
    ranked = Card.ranked_for(answers)
    # A stack built by relaxing the credit filter (its cards fail the strict
    # check) offers swaps from that same relaxed pool; otherwise every Swap
    # button would be disabled. A strict stack keeps the filtered catalogue.
    if ranked.empty? && selected.any? { |card| !card.recommendable_for?(answers) }
      ranked = Card.ranked_for(answers.merge("credit_score" => "I don't know"))
    end
    cards = (selected + ranked).uniq
    {
      cards: cards.map.with_index do |card, index|
        data = card.results_data(index)
        fit = QuizCardFit.new(card, answers)
        data[:recommendedUses] = fit.recommended_uses
        data[:matches] = fit.preferences_met if answers["priorities"].present? && card.catalogue_status != "retired"
        if answers["priorities"].present? && card.recommendable_for?(answers) && card.catalogue_status != "retired"
          data[:matchReasons] = fit.explanation
        end
        data
      end,
      selected: ids.filter_map { |id| cards.index { |card| card.id == id } },
      spending: Array(answers["spending_priorities"]).first(3)
    }
  end
end
