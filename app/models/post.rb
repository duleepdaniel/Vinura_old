class Post < ApplicationRecord
  include ActiveModel::Validations

  attr_accessor :skip_validations

  # validates_with ContentLengthValidator, :minimum=> 70, :maximum=> 199889, unless: :skip_validations

  validates :title, presence: true, unless: :skip_validations

  before_save :purify

  belongs_to :user, optional: false

  has_many :comments, as: :commentable, dependent: :destroy

  has_many :likes, as: :likeable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy

  has_many :taggables, dependent: :destroy
  has_many :tags, through: :taggables

  has_one_attached :image, dependent: :destroy

  extend FriendlyId
  friendly_id :title, use: :slugged

  has_one :draft, as: :draftable, dependent: :destroy

  scope :published, -> { where.missing(:draft) }
  scope :unpublished, -> { where.associated(:draft) }

  def is_published
    draft.nil?
  end

  def publish
    self.draft = nil
    save
  end

  def should_generate_new_friendly_id?
    true
  end

  default_scope { order(created_at: :desc) }

  # after_save_commit lambda {
  #   generate_og_image if body.present? and previous_changes.has_key?(:body)
  # }

  def pure_text
    Nokogiri::HTML(body).xpath('//text()').map(&:text).join('')
            .strip
  end

  def purify
    self.body = ApplicationController.helpers.purify body
  end

  def excerpt
    Nokogiri::HTML(body).xpath('//text()').map(&:text).join(' ').truncate(300)
  end

  def reading_time
    words_per_minute = 150
    text = Nokogiri::HTML(body).at('body').inner_text
    (text.scan(/\w+/).length / words_per_minute).to_i
  end

  def similiar_posts
    Post.joins(:tags)
        .where.not(posts: { id: id })
        .where(tags: { id: tags.ids })
        .or(Post.where(user: user))
        .group(:id)
  end

  def generate_og_image
    image_file_io, image_name = ApplicationController.helpers.create_og_image(title)
    image.attach(io: image_file_io, filename: image_name, content_type: 'image/png')
  end
end
