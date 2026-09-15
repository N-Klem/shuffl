module QuizResponsesHelper
  QUESTION_EMPHASIS = {
    "priorities" => "matters most",
    "spending_priorities" => "your money",

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

  def quiz_question_explanation(question)
    return "Choose up to three. One is enough if that's all you need." if question[:type] == :ranked
    {
      "open_credit_cards" => "A little context for your next card. Every goal is open to you.",
      "credit_score" => "This helps compare cards' typical credit requirements. No credit check.",
      "pays_in_full" => "How you repay matters alongside rewards and fees.",
      "monthly_card_spend" => "An estimate is fine. You can adjust your spending on the results page.",
      "annual_fee_tolerance" => "We'll use this to weigh the cost against the benefits.",
      "employment_status" => "This helps us consider student and more accessible cards.",
      "documented_income" => "This helps us consider more accessible options.",
      "annual_income" => "A rough range helps us weigh annual fees. We don't need an exact figure.",
      "international_travel" => "This helps us weigh foreign transaction fees.",
      "signup_bonus_interest" => "Tell us whether a welcome offer matters to you.",
      "online_shopping" => "This helps us weigh online shopping benefits.",
      "perks_interest" => "We'll look for these benefits in the card catalogue."
    }.fetch(question[:key], "Choose the answer that fits you best.")
  end

  def quiz_question_heading(question)
    prompt = question[:prompt].sub(/\s*\(pick up to \d+\)/, "")
    phrase = QUESTION_EMPHASIS[question[:key]]
    return prompt unless phrase && prompt.include?(phrase)

    before, emphasis, after = prompt.partition(phrase)
    safe_join([ before, tag.span(emphasis, class: "quiz-emphasis"), after ])
  end
end
