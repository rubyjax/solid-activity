class EnrichPostJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 1.second, attempts: 3

  after_discard do |_job, _error|
    post_id = arguments.first
    mark_failed!(post_id)
  end

  def self.mark_failed!(post_id)
    post = Post.find_by(id: post_id)
    return unless post&.pending?

    post.update!(status: :failed)
    post.broadcast_replace_to "activity",
      target: ActionView::RecordIdentifier.dom_id(post),
      partial: "posts/post",
      locals: { post: post }
  end

  def perform(post_id)
    post = Post.find(post_id)
    return unless post.pending?

    post.enrich_summary!
    post.broadcast_replace_to "activity",
      target: ActionView::RecordIdentifier.dom_id(post),
      partial: "posts/post",
      locals: { post: post }
  end
end
