class Comment < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :commentable, polymorphic: true
  belongs_to :user
  belongs_to :parent, class_name: 'Comment', optional: true
  has_many :comments, foreign_key: :parent_id, dependent: :nullify

  validates :body, presence: true, length: { minimum: 2, maximum: 500 }
  has_many :likes, as: :likeable, dependent: :destroy

  after_create_commit :notify_recipient
  before_destroy :cleanup_notifications

  has_noticed_notifications model_name: 'Notification'

  default_scope { order(created_at: :desc) }

  extend FriendlyId
  friendly_id :body, use: :slugged

  has_one :trash, as: :trashable, dependent: :destroy

  scope :untrashed, -> { where.missing(:trash) }
  scope :trashed, -> { where.associated(:trash) }

  def is_trashed
    !trash.nil?
  end

  def untrash_it
    trash.destroy
  end

  def trash_it
    Trash.create(trashable: self, user: user)
    cleanup_notifications
  end

  def normalize_friendly_id(string)
    super[0..12]
  end

  def title
    body.truncate(100)
  end

  def hash_id
    Digest::SHA1.hexdigest(id.to_s)
  end

  private

  def notify_recipient
    if parent_id.nil?
      if user != commentable.user
        CommentNotification.with(comment: self, commentable: commentable).deliver_later(commentable.user)
      end
    else
      commenter_equals_parent_commenter = user == parent.user
      unless commenter_equals_parent_commenter
        ReplyNotification.with(comment: self, commentable: commentable).deliver_later(parent.user)
      end

      commenter_equals_with_author = user == commentable.user
      unless commenter_equals_with_author
        CommentNotification.with(comment: self, commentable: commentable).deliver_later(commentable.user)
      end
    end
  end

  def cleanup_notifications
    notifications_as_comment.destroy_all
  end
end
