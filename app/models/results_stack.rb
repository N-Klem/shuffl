require "json"

# Uses live records; historical recommendations retain their original IDs.
class ResultsStack
  def initialize(quiz_response)
    @quiz_response = quiz_response
  end

  def payload
    answers = JSON.parse(@quiz_response.answers.presence || "{}")
    ids = JSON.parse(@quiz_response.top_card_ids.presence || "[]")
    ranked = Card.ranked_for(answers)
    cards = (ids.filter_map { |id| Card.find_by(id: id) } + ranked).uniq
    {
      cards: cards.map.with_index do |card, index|
        data = card.results_data(index)
        data[:recommendedUses] = QuizCardFit.new(card, answers).recommended_uses
        if answers["priorities"].present? && card.recommendable_for?(answers) && card.catalogue_status != "retired"
          data[:matchReasons] = QuizCardFit.new(card, answers).explanation
        end
        data
      end,
      selected: ids.filter_map { |id| cards.index { |card| card.id == id } }
    }
  end
end
