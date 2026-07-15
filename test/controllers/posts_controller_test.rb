require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "poster@example.com", password: "password123", password_confirmation: "password123")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "create enqueues enrich job and inserts pending post" do
    assert_enqueued_with(job: EnrichPostJob) do
      assert_difference("Post.count", 1) do
        post posts_url, params: { post: { body: "Live from Solid" } }
      end
    end

    created = Post.last
    assert created.pending?
    assert_redirected_to root_url
  end

  test "create rejects blank body" do
    assert_no_difference("Post.count") do
      post posts_url, params: { post: { body: "" } }
    end
    assert_response :unprocessable_entity
  end
end
