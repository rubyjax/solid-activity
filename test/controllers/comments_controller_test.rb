require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "commenter@example.com", password: "password123", password_confirmation: "password123")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @post = Post.create!(user: @user, body: "Ready post", status: :ready, summary: "Ready post")
  end

  test "create adds comment" do
    assert_difference("Comment.count", 1) do
      post post_comments_url(@post), params: { comment: { body: "Agreed" } }
    end
  end
end
