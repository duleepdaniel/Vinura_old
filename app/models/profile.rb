class Profile < ApplicationRecord
  belongs_to :user, foreign_key: 'user_id'
  validates_uniqueness_of :user_id, message: 'Can not have more than one profiles'
  has_one_attached :avatar

  enum :appearance, { light: 0, dark: 1 }

  def get_name
    name || user.username
  end

  def my_avatar
    (self and avatar.attached?) ? avatar : 'cute.jpg'
  end
end
