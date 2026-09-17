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
    return "Choose up to three. Choose No preference on its own." if question[:type] == :multi
    return "Tap up to three, in order. Your first tap is your top priority." if question[:type] == :ranked
    {
      "open_credit_cards" => "If you choose Recommend for me, this helps us balance extra coverage against the number of cards to manage.",
      "credit_score" => "We only recommend cards with recorded guidance matching your range. If you don’t know it, we can’t establish a match. No credit check or approval guarantee.",
      "reward_management" => "Changing categories add work. We count them only as flexible opportunities, never as permanent rewards for your spending.",
      "first_card_management" => "This helps us choose between everyday simplicity, no annual fee and a focused spending role.",
      "next_card_management" => "This changes how we weigh category management, fees and a clear spending role.",
      "groceries_where" => "Supermarket bonuses may exclude superstores, wholesale clubs or online orders. Your answer changes which rewards count.",
      "shopping_where" => "We only count retailer and membership rewards when your answer supports them.",
      "dining_where" => "We distinguish restaurant rewards from explicitly supported delivery rewards.",
      "travel_booking" => "Portal-only rewards do not count as direct-booking rewards.",
      "transport_spending" => "Gas, EV charging and transit have different recorded reward rules.",
      "entertainment_spending" => "Streaming rewards do not automatically cover events or cinemas.",
      "bills_spending" => "Phone plans may have specific rewards. We do not assume rent accepts credit cards or earns rewards.",
      "foreign_purchases" => "More frequent foreign-currency use gives fee-free coverage more weight.",
      "dining_providers" => "We only count a provider credit when that provider is named in our recorded terms.",
      "credit_providers" => "Credits count only where they match your existing spending, with the recorded enrolment conditions.",
      "pays_in_full" => "How you repay matters alongside rewards and fees.",
      "monthly_card_spend" => "This helps us weigh ongoing annual fees against your spending level. It is not a reward or bonus estimate.",
      "annual_fee_budget" => "The total ongoing annual fees across all recommended cards must fit this budget. Enter 0 for no annual fees.",
      "stack_size" => "This is a maximum, not a target. We can recommend fewer if extra cards would add little value.",
      "employment_status" => "Student-only cards are considered only when you select Student. We do not infer your income.",
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
