require "application_system_test_case"

class ActivityFeedTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email_address: "sys@example.com", password: "password123", password_confirmation: "password123")
  end

  test "sign in create post and see enriched feed item" do
    visit new_session_url
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password123"
    click_button "Sign in"

    assert_text "Solid Activity"
    fill_in "What's happening?", with: "System test post for Solid"
    click_button "Post"

    assert_text "System test post for Solid"
    assert_text "Processing via Solid Queue"

    perform_enqueued_jobs

    visit root_url
    assert_text "System test post for Solid"
    assert_text "Solid Cache"
  end
end
