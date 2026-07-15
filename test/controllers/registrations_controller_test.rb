require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url
    assert_response :success
  end

  test "should register user and sign in" do
    assert_difference("User.count", 1) do
      post registration_url, params: {
        user: { email_address: "demo@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end
end
