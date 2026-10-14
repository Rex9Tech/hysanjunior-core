# app/models/campus_membership.rb

class CampusMembership < ApplicationRecord
  belongs_to :campus, inverse_of: :campus_memberships
  belongs_to :user

  enum :kind, CampusConstants::MembershipKind::ALL.index_with(&:itself), prefix: true, validate: true

  validates :kind, inclusion: { in: CampusConstants::MembershipKind::ALL }
  validates :user_id, uniqueness: {
    scope: :campus_id,
    conditions: -> { where(discarded_at: nil) }
  }
  validate :user_must_be_teacher_admin

  scope :recent, -> { order(created_at: :desc) }
  scope :by_campus, ->(campus_id) { where(campus_id: campus_id) if campus_id.present? }
  scope :by_kind, ->(kind) { where(kind: kind) if kind.present? }

  private

  def user_must_be_teacher_admin
    return if user.blank?
    return if user.has_role?(IamConstants::Role::TEACHER_ADMIN)

    errors.add(:user_id, :must_be_teacher_admin)
  end
end
