class CommentNotification < Noticed::Base
  deliver_by :database

  def url
    params[:comment].commentable
  end

  def message
    commentable = params[:comment].commentable
    comment = Comment.find(params[:comment][:id])
    user = User.find(comment.user_id)
    { :partial => 'notification/components/comment',
      :locals => {
        commentable: commentable,
        comment: comment,
        user: user
      } }
  end
end
