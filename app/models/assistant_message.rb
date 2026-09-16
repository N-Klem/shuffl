class AssistantMessage < ApplicationRecord
  belongs_to :user
  class LimitReached < StandardError; end

  validates :question, length: { in: 1..1500 }
  validates :status, inclusion: { in: %w[pending completed failed cleared] }

  def self.daily_limit
    ENV.fetch("ASSISTANT_USER_DAILY_LIMIT", "20").to_i.clamp(0, 100)
  end

  def self.reserve!(user:, conversation_key:, question:)
    transaction do
      # PostgreSQL serializes reservations across every Rails worker/dyno. Never
      # hold this lock during an API call. Failed calls still consume the quota.
      connection.execute("SELECT pg_advisory_xact_lock(738294610)")
      today = where(created_at: Time.current.utc.beginning_of_day..)
      mine = where(user: user)
      raise LimitReached, "You've reached today's chat limit. Please come back tomorrow (UTC)." if today.where(user: user).count >= daily_limit
      if today.count >= ENV.fetch("ASSISTANT_GLOBAL_DAILY_LIMIT", "200").to_i.clamp(0, 10_000)
        raise LimitReached, "Chat has reached its daily limit. Please come back tomorrow (UTC)."
      end
      if mine.where(created_at: 1.minute.ago..).count >= 6 || mine.where(status: "pending", created_at: 2.minutes.ago..).exists?
        raise LimitReached, "Please wait a moment before sending another message."
      end
      create!(user: user, conversation_key: conversation_key, question: question)
    end
  end

  def self.remaining_for(user)
    used = where(user: user, created_at: Time.current.utc.beginning_of_day..).count
    [ daily_limit - used, 0 ].max
  end
end
