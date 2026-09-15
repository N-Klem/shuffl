require "json"
require "uri"

# Research awaiting human review. These records are deliberately separate from
# Card: incomplete terms must not enter browsing, saved wallets or quiz results.
class CardCandidate < ApplicationRecord
  validates :source_key, :name, :country, :currency, presence: true
  validates :source_key, uniqueness: true, format: { with: /\A(?:us|gb)-[a-z0-9-]+\z/ }
  validates :shortlist_position, numericality: { only_integer: true, greater_than: 0 }
  validates :country, inclusion: { in: %w[US GB] }
  validates :review_status, inclusion: { in: %w[pending reviewed rejected] }
  validates :reviewed_by, :reviewed_at, presence: true, unless: -> { review_status == "pending" }
  validate :market_matches
  validate :research_is_well_formed

  scope :in_shortlist_order, -> { order(:shortlist_position, :id) }

  # A repeat import never overwrites manual corrections or review decisions.
  # Edit an existing candidate explicitly rather than treating seeds as updates.
  def self.import_file!(path)
    document = JSON.parse(File.read(path))
    raise ArgumentError, "Unsupported catalogue version" unless document.fetch("schema_version") == 1

    rows = document.fetch("cards")
    raise ArgumentError, "cards must be an array" unless rows.is_a?(Array)
    keys = rows.map { |row| row.fetch("source_key") }
    raise ArgumentError, "Duplicate source keys" unless keys.uniq.length == keys.length

    added = 0
    transaction do
      rows.each do |row|
        candidate = find_or_initialize_by(source_key: row.fetch("source_key"))
        next if candidate.persisted?

        candidate.assign_attributes(row.slice("shortlist_position", "name", "country", "currency", "research"))
        candidate.save!
        added += 1
      end
    end
    { added: added, preserved: rows.length - added }
  end

  private

  def market_matches
    errors.add(:currency, "must match the country") unless { "US" => "USD", "GB" => "GBP" }[country] == currency
    errors.add(:source_key, "must match the country") unless source_key.to_s.start_with?("#{country.to_s.downcase}-")
  end

  def research_is_well_formed
    unless research.is_a?(Hash)
      errors.add(:research, "must be an object")
      return
    end
    errors.add(:research, "needs an issuer") if research["issuer"].blank?
    %w[rewards sources review_flags quiz_tags recommendation_conditions].each do |key|
      errors.add(:research, "#{key} must be an array") unless research[key].is_a?(Array)
    end
    fees = research["fees"]
    if fees.is_a?(Hash)
      %w[annual monthly foreign_purchase_percent].each do |key|
        value = fees[key]
        next if value.nil?
        errors.add(:research, "#{key} must be a non-negative decimal string or null") unless decimal_string?(value)
      end
    else
      errors.add(:research, "fees must be an object")
    end
    if research["rewards"].is_a?(Array)
      research["rewards"].each do |rule|
        unless rule.is_a?(Hash) && rule["category"].present? && decimal_string?(rule["rate"])
          errors.add(:research, "each reward needs a category and non-negative decimal rate")
          next
        end
        units = country == "US" ? %w[points_per_USD miles_per_USD cashback_percent] : %w[points_per_GBP Avios_per_GBP cashback_percent gift_card_reward_percent reward_percent]
        errors.add(:research, "reward unit must match the market") unless units.include?(rule["unit"])
      end
    end
    sources = research["sources"]
    if !sources.is_a?(Array) || sources.empty?
      errors.add(:research, "needs at least one source")
      return
    end
    sources.each do |source|
      unless source.is_a?(Hash)
        errors.add(:research, "source must be an object")
        next
      end
      begin
        uri = URI.parse(source.fetch("url"))
        raise ArgumentError unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
        Date.iso8601(source.fetch("checked_on"))
      rescue KeyError, ArgumentError, TypeError, URI::InvalidURIError
        errors.add(:research, "sources need an HTTPS URL and ISO check date")
      end
    end
  end

  def decimal_string?(value)
    value.is_a?(String) && value.match?(/\A\d+(?:\.\d+)?\z/)
  end
end
