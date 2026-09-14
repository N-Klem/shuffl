ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class QuizFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @card = Card.create!(name: "Quiz test card", issuer: "Test", network: "Visa",
                         card_type: "Credit", annual_fee: 0, reward_rate: 1, best_for: "Cashback")
  end

  # The step field carries the raw index, which is what the server validates
  # against. Reading it back is how these tests follow a flow that can skip
  # questions rather than assuming a fixed sequence.
  def current_index
    css_select("input[name='step']").first["value"].to_i
  end

  def answer_current(choice = :last)
    index = current_index
    question = Card::CORE_QUESTIONS[index]
    answer =
      case question[:type]
      when :ranked then question[:options].first(3)
      else choice == :first ? question[:options].first : question[:options].last
      end
    post quiz_responses_path, params: { step: index, answer: answer }
    question
  end

  test "runs the core questions, skipping the conditional one when it does not apply" do
    get new_quiz_response_path
    assert_response :success
    # rewards_type is hidden until top_priority is "Earning rewards", so a fresh
    # visitor sees nine of the ten.
    assert_select "[role='progressbar'][aria-valuemax='9']"
    assert_select ".quiz-bubble", count: 9
  end

  test "choosing Earning rewards reveals the conditional question and the count follows" do
    get new_quiz_response_path
    until current_index == Card::CORE_QUESTIONS.index { |q| q[:key] == "top_priority" }
      answer_current
      follow_redirect!
    end

    post quiz_responses_path, params: { step: current_index, answer: "Earning rewards" }
    follow_redirect!

    assert_select ".quiz-bubble", count: 10
    assert_select "h1", text: /rewards do you care about most/
  end

  test "a ranked answer keeps the order it was given, not the order of the options" do
    get new_quiz_response_path
    ranked_index = Card::CORE_QUESTIONS.index { |q| q[:type] == :ranked }
    until current_index == ranked_index
      answer_current
      follow_redirect!
    end

    options = Card::CORE_QUESTIONS[ranked_index][:options]
    reversed = [ options[2], options[1], options[0] ]
    post quiz_responses_path,
         params: { step: ranked_index, answer: options.first(3), ordered: reversed.join("") }
    follow_redirect!

    get new_quiz_response_path(step: ranked_index)
    assert_response :success
  end

  test "rejects an invalid answer and a stale step without losing progress" do
    get new_quiz_response_path
    post quiz_responses_path, params: { step: 0, answer: "not a real option" }
    assert_response :unprocessable_entity
    assert_select "input[name='step'][value='0']"

    first = Card::CORE_QUESTIONS.first
    post quiz_responses_path, params: { step: 0, answer: first[:options].first }
    follow_redirect!
    # Re-posting step 0 is a stale form from another tab and must not rewind.
    post quiz_responses_path, params: { step: 0, answer: first[:options].last }
    follow_redirect!
    get new_quiz_response_path(step: 0)
    assert_select "input[checked][value=?]", first[:options].first
  end

  test "saving progress while signed out creates an anonymous draft and asks for sign-in" do
    get new_quiz_response_path
    answer_current
    follow_redirect!

    assert_difference "QuizResponse.drafts.count", 1 do
      post save_progress_quiz_responses_path
    end
    assert_redirected_to new_user_session_path

    draft = QuizResponse.drafts.order(:id).last
    assert_nil draft.user_id, "an unauthenticated draft should not belong to anyone yet"
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
    get root_path                     # any request triggers claim_quiz_response
    assert_equal user.id, draft.reload.user_id, "the draft should be attached on sign-in"

    # A fresh session with no in-progress answers should restore from the draft
    # and land on the first question still unanswered.
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
    # No new record: the draft is the one that gets completed.
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
    assert_not_nil draft.completed_at, "the draft should now be complete"
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

    # The home page continuity prompt reads latest_quiz_response; an unfinished
    # quiz must not be offered as "your results".
    get root_path
    assert_response :success
    assert_select "a", text: /View your results/, count: 0
  end
end
