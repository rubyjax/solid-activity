require "test_helper"

class EnrichPostJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(email_address: "j@example.com", password: "password123", password_confirmation: "password123")
    @post = Post.create!(user: @user, body: "a" * 200, status: :pending)
  end

  test "enriches summary and marks ready" do
    EnrichPostJob.perform_now(@post.id)
    @post.reload
    assert @post.ready?
    assert_equal 141, @post.summary.length # 140 chars + ellipsis
    assert @post.summary.end_with?("…")
  end

  test "mark_failed! sets failed status" do
    EnrichPostJob.mark_failed!(@post.id)
    assert @post.reload.failed?
  end
end
