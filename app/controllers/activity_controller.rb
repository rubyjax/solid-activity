class ActivityController < ApplicationController
  def index
    @posts = Post.includes(:user, :comments).order(created_at: :desc)
    @post = Post.new
  end
end
