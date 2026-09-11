module QuizResponsesHelper
  QUESTION_EMPHASIS = {
    "credit_score" => "credit score range",
    "open_credit_cards" => "open credit cards",
    "annual_income" => "annual income",
    "employment_status" => "employment status",
    "documented_income" => "regular source of income",
    "biggest_expense" => "biggest monthly expense",
    "monthly_card_spend" => "spend per month",
    "second_expense" => "second-biggest spending category",
    "rewards_type" => "rewards",
    "perks_interest" => "perks",
    "signup_bonus_interest" => "sign-up bonuses",
    "annual_fee_tolerance" => "annual fees",
    "international_travel" => "travel internationally",
    "loyalty_program" => "preferred airline or hotel chain",
    "online_shopping" => "shop a lot online",
    "top_priority" => "#1 priority"
  }.freeze

  def quiz_question_heading(question)
    prompt = question[:prompt].sub(/\s*\(pick up to \d+\)/, "")
    phrase = QUESTION_EMPHASIS[question[:key]]
    return prompt unless phrase && prompt.include?(phrase)

    before, emphasis, after = prompt.partition(phrase)
    safe_join([ before, tag.span(emphasis, class: "quiz-emphasis"), after ])
  end
end
