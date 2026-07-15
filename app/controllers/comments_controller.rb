class CommentsController < ApplicationController
  before_action :set_post

  def create
    @comment = @post.comments.new(comment_params)
    @comment.user = Current.user

    if @comment.save
      @comment.broadcast_append_to "activity",
        target: ActionView::RecordIdentifier.dom_id(@post, :comments),
        partial: "comments/comment",
        locals: { comment: @comment }
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
      end
    else
      redirect_to root_path, alert: "Comment can't be blank."
    end
  end

  def destroy
    @comment = @post.comments.find(params[:id])
    if @comment.user_id == Current.user.id
      @comment.destroy!
    end
    redirect_to root_path
  end

  private
    def set_post
      @post = Post.find(params[:post_id])
    end

    def comment_params
      params.require(:comment).permit(:body)
    end
end
