# Search the small catalogue for the best combined coverage within both limits.
# Coverage counts once; beyond the two-card minimum, extra roles must add value.
class QuizRecommendation
  attr_reader :answers, :fits

  def initialize(answers)
    @answers = answers
    @fits = Card.available.order(:id).select { |card| card.recommendable_for?(answers) }
                .map { |card| QuizCardFit.new(card, answers) }
  end

  def ranked_cards
    fits.sort_by { |fit| [-fit.score, fit.card.annual_fee || Float::INFINITY, fit.card.id] }.map(&:card)
  end

  def cards
    budget = answers.fetch("annual_fee_budget", "0").to_d
    candidates = fits.select { |fit| fit.card.annual_fee && fit.card.annual_fee <= budget }
    best, best_score, best_fee = [], -Float::INFINITY, Float::INFINITY
    maximum = [Card.stack_size_limit(answers), candidates.size].min
    # Recommend at least two choices unless the user asks for one. Suitability
    # and the combined fee budget remain hard limits, even for this minimum.
    pair_fits = maximum >= 2 && candidates.combination(2).any? { |pair| pair.sum { |fit| fit.card.annual_fee } <= budget }
    minimum = pair_fits ? 2 : 1
    minimum.upto(maximum) do |size|
      candidates.combination(size) do |stack|
        fee = stack.sum { |fit| fit.card.annual_fee }
        next if fee > budget
        value = stack_score(stack)
        if value > best_score + 0.000001 || ((value - best_score).abs < 0.000001 && fee < best_fee)
          best, best_score, best_fee = stack, value, fee
        end
      end
    end
    # Lead with the strongest contribution, then order by what each card adds.
    ordered = []
    until best.empty?
      next_fit = best.max_by { |fit| stack_score(ordered + [fit]) - stack_score(ordered) }
      ordered << next_fit
      best = best - [next_fit]
    end
    ordered.map(&:card)
  end

  def stack_score(stack)
    coverage = {}
    stack.each do |fit|
      fit.features.each { |key, value| coverage[key] = [coverage.fetch(key, 0), value].max }
    end
    coverage.values.sum - stack.sum(&:penalty) - stack.size * complexity_cost
  end

  def complexity_cost
    return 1.0 unless answers["stack_size"] == "Recommend for me"
    { "None right now" => 2.5, "1–2" => 2.0, "3–5" => 1.5, "6+" => 1.0 }.fetch(answers["open_credit_cards"], 2.0)
  end
end
