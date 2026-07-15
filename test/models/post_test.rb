require "test_helper"

class PostTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "author@example.com", password: "password123", password_confirmation: "password123")
  end

  test "requires body" do
    post = Post.new(user: @user, body: "", status: :pending)
    assert_not post.valid?
    assert_includes post.errors[:body], "can't be blank"
  end

  test "defaults status to pending" do
    post = Post.create!(user: @user, body: "Hello feed")
    assert post.pending?
  end

  test "belongs to user" do
    post = Post.create!(user: @user, body: "Hello")
    assert_equal @user, post.user
  end
end
