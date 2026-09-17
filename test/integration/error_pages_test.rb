ENV["RAILS_ENV"] ||= "test"
require_relative "../../config/environment"
require "rails/test_help"

class ErrorPagesTest < ActionDispatch::IntegrationTest
  test "an unknown path renders the branded not-found page inside the layout" do
    get "/definitely-not-a-page"
    assert_response :not_found
    assert_select "h1", text: "That page isn't in the deck."
    assert_select ".site-nav .wordmark"
    assert_select "a[href=?]", root_path, text: "Back to home"
  end

  test "a missing record renders the same page" do
    get card_path(id: 999_999)
    assert_response :not_found
    assert_select "h1", text: "That page isn't in the deck."
  end

  test "asset-like paths are left to their own handlers" do
    get "/assets/nothing-here.css"
    assert_response :not_found
    assert_select "h1", text: "That page isn't in the deck.", count: 0
  end
end
