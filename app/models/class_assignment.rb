# app/models/class_assignment.rb

class ClassAssignment < ApplicationRecord
  belongs_to :school_class, inverse_of: :class_assignments
  belongs_to :user

  validates :user_id, uniqueness: {
    scope: :school_class_id,
    conditions: -> { where(discarded_at: nil) }
  }
  validate :user_must_be_teacher_admin
  validate :user_must_belong_to_campus

  scope :recent, -> { order(created_at: :desc) }
  scope :by_school_class, ->(school_class_id) { where(school_class_id: school_class_id) if school_class_id.present? }
  scope :by_campus, ->(campus_id) {
    if campus_id.blank?
      all
    else
      joins(:school_class).where(school_classes: { campus_id: campus_id })
    end
  }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }

  private

  def user_must_be_teacher_admin
    return if user.blank?
    return if user.has_role?(IamConstants::Role::TEACHER_ADMIN)

    errors.add(:user_id, :must_be_teacher_admin)
  end

  def user_must_belong_to_campus
    return if user.blank? || school_class.blank?

    membership = CampusMembership.kept.find_by(
      campus_id: school_class.campus_id,
      user_id: user_id,
      kind: CampusConstants::MembershipKind::TEACHER_ADMIN
    )
    return if membership.present?

    errors.add(:user_id, :must_belong_to_campus)
  end
end
