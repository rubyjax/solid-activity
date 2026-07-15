class PurgeStalePendingPostsJob < ApplicationJob
  queue_as :default

  def perform
    Post.pending.where("created_at < ?", 15.minutes.ago).find_each(&:destroy!)
  end
end
