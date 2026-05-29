class PostsController < ApplicationController
  before_action :set_current_user
  include RailsAuditLog::Controller
  audit_log_actor { @current_user }

  def create
    Post.create!(title: params[:title])
    head :ok
  end

  private

  def set_current_user
    @current_user = User.find_by(id: params[:user_id])
  end
end
