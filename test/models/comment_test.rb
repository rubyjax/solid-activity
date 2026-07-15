require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "c@example.com", password: "password123", password_confirmation: "password123")
    @post = Post.create!(user: @user, body: "Parent post")
  end

  test "requires body" do
    comment = Comment.new(user: @user, post: @post, body: "")
    assert_not comment.valid?
  end

  test "belongs to post and user" do
    comment = Comment.create!(user: @user, post: @post, body: "Nice")
    assert_equal @post, comment.post
    assert_equal @user, comment.user
  end
end
