ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"
require "tempfile"

class CardCandidateTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("data/real_cards/catalogue.json")
    @document = JSON.parse(File.read(@path))
  end

  test "imports all 50 into review without changing the live catalogue" do
    assert_no_difference [ "Card.count", "WalletItem.count", "StackCard.count" ] do
      assert_difference "CardCandidate.count", 50 do
        assert_equal({ added: 50, preserved: 0 }, CardCandidate.import_file!(@path))
      end
    end
    assert_equal 30, CardCandidate.where(country: "US", currency: "USD").count
    assert_equal 20, CardCandidate.where(country: "GB", currency: "GBP").count
    assert_equal [ "pending" ], CardCandidate.distinct.pluck(:review_status)
    candidate = CardCandidate.find_by!(source_key: "gb-ms-shopping-plus")
    assert_nil candidate.research.dig("fees", "annual")
    assert_nil candidate.research["credit_score_min"]
  end

  test "repeat import preserves manual facts and review decisions" do
    CardCandidate.import_file!(@path)
    candidate = CardCandidate.first
    candidate.update!(name: "Manually corrected name", review_status: "reviewed", reviewed_by: "Noah", reviewed_at: Time.current, review_notes: "Checked against issuer")
    original_time = candidate.updated_at
    assert_no_difference "CardCandidate.count" do
      assert_equal({ added: 0, preserved: 50 }, CardCandidate.import_file!(@path))
    end
    assert_equal "Manually corrected name", candidate.reload.name
    assert_equal "reviewed", candidate.review_status
    assert_equal original_time, candidate.updated_at
  end

  test "an invalid later record rolls back the entire batch" do
    @document["cards"][1]["currency"] = "GBP"
    with_document do |path|
      assert_no_difference "CardCandidate.count" do
        assert_raises(ActiveRecord::RecordInvalid) { CardCandidate.import_file!(path) }
      end
    end
  end

  test "duplicate source keys are rejected rather than silently ignored" do
    @document["cards"] << @document["cards"].first
    with_document do |path|
      assert_no_difference "CardCandidate.count" do
        assert_raises(ArgumentError) { CardCandidate.import_file!(path) }
      end
    end
  end

  test "invalid rates URLs and cross-market units fail validation" do
    candidate = CardCandidate.new(@document["cards"].first)
    candidate.research["fees"]["annual"] = "-95"
    candidate.research["rewards"][0]["unit"] = "points_per_GBP"
    candidate.research["sources"][0]["url"] = "javascript:alert(1)"
    assert_not candidate.valid?
    assert candidate.errors[:research].any? { |e| e.include?("non-negative") }
    assert candidate.errors[:research].any? { |e| e.include?("market") }
    assert candidate.errors[:research].any? { |e| e.include?("HTTPS") }
  end

  test "reviewed and rejected records need reviewer attribution" do
    candidate = CardCandidate.new(@document["cards"].first)
    candidate.review_status = "reviewed"
    assert_not candidate.valid?
    assert candidate.errors[:reviewed_by].present?
    assert candidate.errors[:reviewed_at].present?
  end

  private

  def with_document
    Tempfile.create([ "card-candidates", ".json" ]) do |file|
      file.write(JSON.generate(@document))
      file.flush
      yield file.path
    end
  end
end
