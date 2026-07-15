class PostsController < ApplicationController
  before_action :set_post, only: :destroy

  def create
    @post = Current.user.posts.new(post_params)
    @post.status = :pending

    if @post.save
      EnrichPostJob.perform_later(@post.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path, notice: "Post submitted." }
      end
    else
      @posts = Post.includes(:user, :comments).order(created_at: :desc)
      render "activity/index", status: :unprocessable_entity
    end
  end

  def destroy
    if @post.user_id == Current.user.id
      @post.destroy!
      redirect_to root_path, notice: "Post deleted."
    else
      head :forbidden
    end
  end

  private
    def set_post
      @post = Post.find(params[:id])
    end

    def post_params
      params.require(:post).permit(:body)
    end
end
