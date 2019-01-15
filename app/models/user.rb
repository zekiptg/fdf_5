class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :rememberable, :validatable,
    :omniauthable, omniauth_providers: [:facebook, :google_oauth2]
  has_many :orders
  has_many :ranks

  # Tracked Activity
  include PublicActivity::Model
  tracked

  # Soft Deleted With Gem Paranoia
  acts_as_paranoid column: :active, sentinel_value: true,
    without_default_scope: true

  # Pagination
  paginates_per Settings.admin.user_per_page

  scope :sort_by_newest, ->{order("created_at desc")}

  attr_accessor :remember_token

  mount_uploader :profile_img, AvatarUploader

  enum role: [:admin, :staff, :deliver, :customer]

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  validates :name, presence: true,
    length: {maximum: Settings.validates.user.name.length.maximum}
  validates :email, presence: true,
    format: {with: VALID_EMAIL_REGEX},
    uniqueness: {case_sensitive: false}
  validates :phone, presence: true,
    length: {minimum: Settings.validates.user.phone.length.minimum},
    uniqueness: {case_sensitive: false}, numericality: true
  validates :password, presence: true,
    length: {minimum: Settings.validates.user.password.length.minimum},
    allow_nil: true

  validate :profile_size

  def paranoia_restore_attributes
    {
      deleted_at: nil,
      active: true
    }
  end

  def paranoia_destroy_attributes
    {
      deleted_at: current_time_from_proper_timezone,
      active: false
    }
  end

  def admin?
    return true if role == "admin"
    false
  end

  class << self
    def new_with_session params, session
      super.tap do |user|
        if data = session["devise.facebook_data"] &&
          session["devise.facebook_data"]["extra"]["raw_info"]
          user.email = data["email"] if user.email.blank?
        end
      end
    end

    def admin_array
      return User.where(role: 0)
    end

    def from_omniauth auth
      where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
        user.email = auth.info.email
        user.password = Devise.friendly_token[0,20]
        user.name = auth.info.name
        user.social_img = auth.info.image
      end
    end
  end

  private

  # Validates the size of an uploaded picture.
  def size_notify
    errortext = I18n.t("layouts.errors.userlogin.updatingform.avatarsize")
    errors.add(:profile_img, errortext)
  end

  def profile_size
    limitsize = Settings.validates.user.avatar.size.maximum.megabytes
    size_notify if profile_img.size > limitsize
  end
end
