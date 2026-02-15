# frozen_string_literal: true

class User < ApplicationRecord
  include PasswordValidations

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :password_expirable

  # Associations
  has_one :user_profile, dependent: :destroy
  has_one :company, through: :user_profile

  has_many :orders, foreign_key: :ordered_by_user_id, dependent: :restrict_with_error,
           inverse_of: :ordered_by_user

  # Callbacks
  after_create :create_user_profile_from_domain

  # Delegations
  delegate :role, :member_status, :name, :phone, to: :user_profile, allow_nil: true
  delegate :normal?, :company_admin?, :internal_admin?, :manufacturer_user?, to: :user_profile, allow_nil: true, prefix: false

  # Instance methods
  def current_manufacturer
    user_profile&.manufacturer
  end

  def active_for_authentication?
    super && user_profile&.active?
  end

  def inactive_message
    if user_profile&.pending?
      :pending_approval
    elsif user_profile&.rejected?
      :account_rejected
    elsif user_profile.nil? || user_profile&.unassigned?
      :unassigned_company
    else
      super
    end
  end

  def current_company
    # メーカーはプラットフォーム共通のため会社に属さない。会社ユーザーのみ company を返す
    user_profile&.company
  end

  def company_id
    user_profile&.company_id
  end

  private

  def create_user_profile_from_domain
    # メーカーアカウント（seed: maker-*@platform.example.com）は seed でプロファイルを明示作成するためスキップ
    return if email.to_s.match?(/\Amaker-[a-z0-9-]+@platform\.example\.com\z/i)

    company = Company.find_by_email_domain(email)
    manufacturer = company.blank? ? Manufacturer.find_by_email_domain(email) : nil

    profile = build_user_profile(
      name: email.split("@").first,
      company: company,
      manufacturer_id: manufacturer&.id
    )

    if company
      profile.member_status = :pending
      profile.save!

      ApprovalRequest.create!(
        user_profile: profile,
        company: company,
        status: :pending
      )
    elsif manufacturer
      profile.member_status = :active
      profile.save!
    else
      profile.member_status = :unassigned
      profile.save!
    end
  end
end
