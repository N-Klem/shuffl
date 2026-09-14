class QuizResponsesController < ApplicationController
  QUESTIONS = Card::CORE_QUESTIONS

  def new
    session[:quiz_answers] ||= {}
    session[:quiz_step] = current_step
    if params[:step].present?
      requested = params[:step].to_i
      session[:quiz_step] = requested if requested.between?(0, current_step)
    end
    prepare_question
  end

  def create
    session[:quiz_answers] ||= {}
    session[:quiz_step] = current_step
    # Ignore repeated submissions and forms left open in another tab.
    unless params[:step].to_s == current_step.to_s
      return redirect_to new_quiz_response_path, status: :see_other
    end

    question = QUESTIONS[current_step]
    values = submitted_values(question)
    # A ranked answer arrives already in the visitor's chosen order and is stored
    # that way, because position is the signal: first place scores 3, second 2,
    # third 1.
    valid_count =
      case question[:type]
      when :multi, :ranked then values.size.between?(1, question[:max_select])
      else values.size == 1
      end

    unless valid_count && (values - question[:options]).empty?
      prepare_question
      @error =
        case question[:type]
        when :ranked then "Pick up to #{question[:max_select]}, in the order that matters most."
        when :multi then "Choose between 1 and #{question[:max_select]} answers."
        else "Choose one answer to continue."
        end
      return render :new, status: :unprocessable_entity
    end

    session[:quiz_answers][question[:key]] =
      [ :multi, :ranked ].include?(question[:type]) ? values : values.first

    next_step = next_visible_step(current_step)
    if next_step
      session[:quiz_step] = next_step
      redirect_to new_quiz_response_path, status: :see_other
    else
      top_cards = Card.ranked_for(session[:quiz_answers]).first(5)
      @quiz_response = QuizResponse.create!(
        user: current_user,
        answers: session[:quiz_answers].to_json,
        top_card_ids: top_cards.map(&:id).to_json,
        completed_at: Time.current
      )
      session[:quiz_step] = 0
      session[:quiz_answers] = {}
      # Remembered so card pages can show how each card ranks for this visitor,
      # and so the result can be attached to their account if they sign up later.
      session[:last_quiz_response_id] = @quiz_response.id
      session[:quiz_finish_id] = @quiz_response.id
      redirect_to @quiz_response, status: :see_other
    end
  end

  def show
    @quiz_response = QuizResponse.find(params[:id])
    @show_quiz_finish = session[:quiz_finish_id].to_s == @quiz_response.id.to_s
    session.delete(:quiz_finish_id) if @show_quiz_finish
    ids = JSON.parse(@quiz_response.top_card_ids)
    @cards = ids.filter_map { |id| Card.find_by(id: id) }
    @results_payload = ResultsStack.new(@quiz_response).payload
  end

  private

  def current_step
    session[:quiz_step].to_i.clamp(0, QUESTIONS.size - 1)
  end

  # Some questions only make sense given an earlier answer -- asking a
  # credit-builder which points currency they prefer wastes a screen. Skipped
  # questions simply never get an answer, and every scoring method treats a
  # missing answer as zero.
  # Ranked answers carry their order in a hidden field, because checkbox
  # submission follows DOM order and position is the signal. Fall back to the
  # checkboxes if the field is absent, so the question still works without JS --
  # unordered, but answered.
  def submitted_values(question)
    checked = Array(params[:answer]).reject(&:blank?).uniq
    return checked unless question[:type] == :ranked

    ordered = params[:ordered].to_s.split("\u001F").reject(&:blank?)
    ordered &= checked
    ordered.presence || checked
  end

  def visible?(question)
    condition = question[:depends_on]
    return true if condition.blank?
    session[:quiz_answers][condition[:key]] == condition[:value]
  end

  def next_visible_step(from)
    ((from + 1)...QUESTIONS.size).find { |index| visible?(QUESTIONS[index]) }
  end

  def previous_visible_step(from)
    (0...from).to_a.reverse.find { |index| visible?(QUESTIONS[index]) }
  end

  # Numbering has to count only the questions this visitor will actually see,
  # or a skipped question leaves a gap ("Question 9 of 10" twice, or a jump).
  def visible_questions
    QUESTIONS.select { |question| visible?(question) }
  end

  def prepare_question
    # A conditional question can become invisible if an earlier answer changed on
    # the way back, so land on the next one the visitor should actually see.
    unless visible?(QUESTIONS[current_step])
      session[:quiz_step] = next_visible_step(current_step) || current_step
    end

    @question = QUESTIONS[current_step]
    @current_index = current_step
    visible = visible_questions
    @step = visible.index(@question).to_i + 1
    @total = visible.size
    @previous_step = previous_visible_step(current_step)
    @selected = Array(session[:quiz_answers][@question[:key]])
  end
end
