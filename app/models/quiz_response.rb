class QuizResponse < ApplicationRecord
  belongs_to :user, optional: true

  # A response with no completed_at is a draft: the visitor saved partway through
  # and intends to come back. It holds the answers given so far and no ranking,
  # because there is nothing to rank yet.
  scope :completed, -> { where.not(completed_at: nil) }
  scope :drafts, -> { where(completed_at: nil) }

  validates :answers, presence: true
  # A finished response must record when it finished; a draft must not, because
  # that absence is exactly what marks it as still in progress.
  validates :completed_at, presence: true, if: -> { top_card_ids.present? }

  def draft?
    completed_at.nil?
  end

  def answers_hash
    JSON.parse(answers.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
