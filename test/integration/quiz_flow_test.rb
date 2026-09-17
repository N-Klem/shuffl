ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @card = Card.create!(name: "Quiz test card", issuer: "Test", network: "Visa",
                         card_type: "Credit", annual_fee: 0, reward_rate: 1, best_for: "Cashback")
  end

  def current_index
    css_select("input[name='step']").first["value"].to_i
  end

  def current_question_key
    css_select("input[name='question_key']").first["value"]
  end

  def submit_answer(answer, ordered: nil)
    post quiz_responses_path, params: {
      step: current_index, answer: answer, ordered: ordered,
      quiz_token: css_select("input[name='quiz_token']").first["value"]
    }
  end

  def answer_current(choice = :last)
    question = Card::QUIZ_QUESTION_POOL.fetch(current_question_key)
    answer = question[:type] == :ranked ? question[:options].first(3) : (choice == :first ? question[:options].first : question[:options].last)
    answer = "300" if question[:type] == :budget
    submit_answer(answer)
    question
  end

  test "every goal and ownership level completes exactly ten questions" do
    Card::GOAL_QUESTIONS.each_key do |goal|
      Card::QUESTION_POOL["open_credit_cards"][:options].each do |ownership|
        reset!
        get new_quiz_response_path
        assert_select ".quiz-bubble", count: 10
        submit_answer([goal]); follow_redirect!
        submit_answer(ownership); follow_redirect!
        8.times do
          assert_select ".quiz-bubble", count: 10
          answer_current
          assert_response :see_other
          follow_redirect!
        end
        assert_response :success
        assert_select "input[name='step']", count: 0
        result = QuizResponse.order(:id).last
        assert_equal 10, result.answers_hash.size
        assert_equal [goal], result.answers_hash["priorities"]
        assert result.completed_at
        assert_equal "Recommend for me", result.answers_hash["stack_size"]
        refute result.answers_hash.key?("pays_in_full")
      end
    end
  end

  test "real catalogue returns no match instead of aspirational cards" do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    get new_quiz_response_path
    submit_answer(["Travel rewards"]); follow_redirect!
    submit_answer("1–2"); follow_redirect!
    submit_answer("Building (300–579)"); follow_redirect!
    7.times { answer_current; follow_redirect! }
    assert_response :success
    assert_equal [], JSON.parse(QuizResponse.order(:id).last.top_card_ids)
    assert_select "h1", "No matching stack yet."
    assert_select "#save-stack", count: 0
    assert_select '[data-controller~="results"]', count: 0
  end

  test "ranked questions render as tap-in-order pills with no board" do
    get new_quiz_response_path
    assert_select ".quiz-options-ranked .quiz-answer input[type=checkbox]", count: 5
    assert_select ".quiz-options-ranked .quiz-rank", count: 5
    assert_select "input[name=ordered]", count: 1
    assert_select ".rank-board", count: 0
    assert_select ".quiz-heading p", text: /Tap up to three, in order/
  end

  test "not knowing the credit score still produces a stack, with a note" do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    get new_quiz_response_path
    submit_answer([ "Cashback" ]); follow_redirect!
    submit_answer("1–2"); follow_redirect!
    submit_answer("I don't know"); follow_redirect!
    7.times { answer_current; follow_redirect! }
    assert_response :success
    assert_select "h1", text: /rewarding/
    assert_select ".footnote", text: /skipped your credit score/
    refute_empty JSON.parse(QuizResponse.order(:id).last.top_card_ids)
  end

  test "first-card quiz recommends a supported real card and saves it to Planned" do
    CardCandidate.import_file!(Rails.root.join("data/real_cards/catalogue.json"))
    Card.publish_us_demo!
    user = User.create!(first_name: "Starter", email: "starter-quiz@example.com", password: "password123")
    sign_in user
    get new_quiz_response_path
    answers = [["Building credit"], "None right now", "No credit history", "1",
               ["Groceries"], "Under $500", "0", "Not a student", "No annual fee", "Supermarkets"]
    answers.each { |answer| submit_answer(answer); follow_redirect! }
    quiz = QuizResponse.order(:id).last
    ids = JSON.parse(quiz.top_card_ids)
    assert_equal [Card.find_by!(source_key: "us-chase-freedom-rise").id], ids
    2.times do
      post save_stack_wallet_items_path, params: { quiz_response_id: quiz.id, card_ids: ids }, as: :json
      assert_response :success
    end
    assert_equal ids.first, user.wallet_items.sole.card_id
    assert_equal "planned", user.wallet_items.sole.status
  end

  test "back allows edits and preserves compatible answers" do
    get new_quiz_response_path
    submit_answer(["Travel rewards"]); follow_redirect!
    submit_answer("1–2"); follow_redirect!
    submit_answer("Good (670–739)"); follow_redirect!
    get new_quiz_response_path(step: 1)
    assert_select "input[checked][value='1–2']"
    submit_answer("3–5"); follow_redirect!
    assert_select "input[checked][value='Good (670–739)']"
    get new_quiz_response_path(step: 0)
    submit_answer(["Building credit"]); follow_redirect!
    assert_select "input[checked][value='3–5']"
    get new_quiz_response_path(step: 2)
    assert_select "input[checked][value='Good (670–739)']"
  end

  test "changing goals drops only incompatible branch answers" do
    get new_quiz_response_path
    submit_answer(["Travel rewards"]); follow_redirect!
    8.times { answer_current; follow_redirect! }
    # Programme preferences are answered; travel frequency is still open.
    get new_quiz_response_path(step: 0)
    submit_answer(["Building credit"]); follow_redirect!
    7.times { answer_current; follow_redirect! }
    assert_equal "next_card_management", current_question_key
    2.times { answer_current; follow_redirect! }
    answers = QuizResponse.order(:id).last.answers_hash
    assert answers.key?("next_card_management")
    refute answers.key?("international_travel")
    assert_equal 10, answers.size
  end

  test "rank order survives back navigation and saving" do
    get new_quiz_response_path
    order = ["Useful perks", "Cashback", "Building credit"]
    submit_answer(order.reverse, ordered: order.join("\u001F")); follow_redirect!
    get new_quiz_response_path(step: 0)
    assert_equal order.join("\u001F"), css_select("input[name='ordered']").first["value"]
    post save_progress_quiz_responses_path
    assert_equal order, QuizResponse.drafts.order(:id).last.answers_hash["priorities"]
  end

  test "invalid and duplicate submissions cannot change the answer" do
    get new_quiz_response_path
    submit_answer(["unknown"])
    assert_response :unprocessable_entity
    old_token = css_select("input[name='quiz_token']").first["value"]
    submit_answer(["Cashback"]); follow_redirect!
    post quiz_responses_path, params: { step: 0, answer: ["Travel rewards"], quiz_token: old_token }
    follow_redirect!
    get new_quiz_response_path(step: 0)
    assert_select "input[name='ordered'][value='Cashback']"
  end

  test "stack size replaces repayment and limits saved recommendations" do
    3.times do |i|
      Card.create!(name: "Extra card #{i}", issuer: "Test", network: "Visa",
                   card_type: "Credit", annual_fee: 0, reward_rate: 1)
    end
    get new_quiz_response_path
    submit_answer(["Useful perks"]); follow_redirect!
    submit_answer("None right now"); follow_redirect!
    answer_current; follow_redirect!
    assert_equal "stack_size", current_question_key
    assert_select "h1", /maximum number of cards/
    submit_answer("2"); follow_redirect!
    6.times { answer_current; follow_redirect! }
    result = QuizResponse.order(:id).last
    assert_equal "2", result.answers_hash["stack_size"]
    assert_operator JSON.parse(result.top_card_ids).size, :<=, 2
    assert_operator JSON.parse(result.top_card_ids).size, :>=, 1
    assert_equal 10, result.answers_hash.size
  end

  test "custom combined budget is validated, restored and respected" do
    Card.create!(name: "Fee card A", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 95, reward_rate: 5)
    Card.create!(name: "Fee card B", issuer: "Test", network: "Visa", card_type: "Credit", annual_fee: 95, reward_rate: 5)
    get new_quiz_response_path
    6.times { answer_current; follow_redirect! }
    assert_equal "annual_fee_budget", current_question_key
    ["", "-1", "Infinity", "100.123"].each do |invalid|
      post quiz_responses_path, params: { step: current_index, answer: "Custom", custom_budget: invalid,
        quiz_token: css_select("input[name='quiz_token']").first["value"] }
      assert_response :unprocessable_entity
    end
    post quiz_responses_path, params: { step: current_index, answer: "Custom", custom_budget: "150.50",
      quiz_token: css_select("input[name='quiz_token']").first["value"] }
    follow_redirect!
    get new_quiz_response_path(step: 6)
    assert_select "input[checked][value='Custom']"
    assert_select "input[name='custom_budget'][value='150.50']"
    submit_answer("100"); follow_redirect!
    3.times { answer_current; follow_redirect! }
    result = QuizResponse.order(:id).last
    assert_equal "100", result.answers_hash["annual_fee_budget"]
    assert_operator Card.where(id: JSON.parse(result.top_card_ids)).sum(:annual_fee), :<=, 100
  end

  test "changing perk priority replaces the tenth question and drops the old answer" do
    get new_quiz_response_path
    submit_answer(["Useful perks"]); follow_redirect!
    7.times { answer_current; follow_redirect! }
    submit_answer(["Dining credits"]); follow_redirect!
    assert_equal "dining_providers", current_question_key
    # Simulate a previously saved final answer, then revise its parent question.
    post save_progress_quiz_responses_path
    draft = QuizResponse.drafts.order(:id).last
    draft.update!(answers: draft.answers_hash.merge("dining_providers" => "Uber Eats").to_json)
    reset!
    user = User.create!(first_name: "Branch", email: "branch-test@example.com", password: "password123")
    draft.update!(user: user)
    sign_in user
    get new_quiz_response_path(step: 8)
    submit_answer(["Shopping or subscription credits"]); follow_redirect!
    assert_equal "credit_providers", current_question_key
    answer_current; follow_redirect!
    result = QuizResponse.order(:id).last
    assert result.answers_hash.key?("credit_providers")
    refute result.answers_hash.key?("dining_providers")
    assert_equal 10, result.answers_hash.size
  end

  test "travel no preference cannot be combined with a named programme" do
    get new_quiz_response_path
    submit_answer(["Travel rewards"]); follow_redirect!
    7.times { answer_current; follow_redirect! }
    assert_equal "travel_programs", current_question_key
    submit_answer(["United MileagePlus", "No preference"])
    assert_response :unprocessable_entity
    submit_answer(["United MileagePlus", "World of Hyatt"]); follow_redirect!
    assert_equal "international_travel", current_question_key
    answer_current; follow_redirect!
    assert_equal ["United MileagePlus", "World of Hyatt"], QuizResponse.order(:id).last.answers_hash["travel_programs"]
  end

  test "ranked goals all contribute and the first one has more weight" do
    credit_card = Card.new(annual_fee: 0, credit_score_min: 600, best_for: "Student", reward_rate: 0)
    credit_first = credit_card.quiz_score("priorities" => ["Building credit", "Cashback"])
    credit_second = credit_card.quiz_score("priorities" => ["Cashback", "Building credit"])
    assert_operator credit_first, :>, credit_second
    assert_operator credit_second, :>, credit_card.quiz_score("priorities" => ["Cashback"])
  end

  test "saving progress while signed out creates an anonymous draft" do
    get new_quiz_response_path
    answer_current
    follow_redirect!

    assert_difference "QuizResponse.drafts.count", 1 do
      post save_progress_quiz_responses_path
    end
    assert_redirected_to new_user_session_path

    draft = QuizResponse.drafts.order(:id).last
    assert_nil draft.user_id
    assert_nil draft.completed_at
    assert_equal 1, draft.answers_hash.size
  end

  test "signing in claims the draft and the quiz resumes where it stopped" do
    get new_quiz_response_path
    answered = []
    3.times do
      answered << answer_current[:key]
      follow_redirect!
    end
    post save_progress_quiz_responses_path
    draft = QuizResponse.drafts.order(:id).last

    user = User.create!(first_name: "Resume", email: "resume-test@example.com", password: "password123")
    sign_in user
    get root_path
    assert_equal user.id, draft.reload.user_id

    reset!
    sign_in user
    get new_quiz_response_path
    assert_response :success
    assert_equal answered.size, current_index,
                 "should resume at the first unanswered question, not the start"
  end

  test "finishing after a save completes the draft instead of leaving a second record" do
    user = User.create!(first_name: "Finish", email: "finish-test@example.com", password: "password123")
    sign_in user

    get new_quiz_response_path
    2.times { answer_current; follow_redirect! }
    post save_progress_quiz_responses_path
    follow_redirect!
    draft = user.quiz_responses.drafts.sole

    get new_quiz_response_path
    assert_no_difference "QuizResponse.count" do
      loop do
        answer_current
        assert_response :see_other
        follow_redirect!
        break unless css_select("input[name='step']").any?
      end
    end

    assert_equal 1, user.quiz_responses.count
    assert_predicate draft.reload, :persisted?
    assert_not_nil draft.completed_at
    assert draft.top_card_ids.present?
    assert_equal 0, user.quiz_responses.drafts.count
  end

  test "a draft never surfaces as the visitor's latest result" do
    user = User.create!(first_name: "Draft", email: "draft-test@example.com", password: "password123")
    sign_in user
    get new_quiz_response_path
    answer_current
    follow_redirect!
    post save_progress_quiz_responses_path
    follow_redirect!

    get root_path
    assert_response :success
    assert_select "a", text: /View your results/, count: 0
  end

  test "legacy completed answers retain their scoring interpretation" do
    merged = Card.scored_answers("open_credit_cards" => "1–2", "growing_focus" => "Better travel rewards")
    assert_equal "Earning rewards", merged["top_priority"]
    assert_equal "Travel points & miles", merged["rewards_type"]
  end
end
