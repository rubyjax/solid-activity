require "test_helper"

class PurgeStalePendingPostsJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email_address: "p@example.com", password: "password123", password_confirmation: "password123")
  end

  test "destroys pending posts older than 15 minutes" do
    stale = Post.create!(user: @user, body: "stale", status: :pending, created_at: 16.minutes.ago)
    fresh = Post.create!(user: @user, body: "fresh", status: :pending)
    ready = Post.create!(user: @user, body: "ready", status: :ready, created_at: 1.hour.ago)

    assert_difference("Post.count", -1) do
      PurgeStalePendingPostsJob.perform_now
    end

    assert_not Post.exists?(stale.id)
    assert Post.exists?(fresh.id)
    assert Post.exists?(ready.id)
  end
end
