# app/models/class_enrollment.rb

class ClassEnrollment < ApplicationRecord
  belongs_to :school_class, inverse_of: :class_enrollments
  belongs_to :user

  enum :status, CampusConstants::EnrollmentStatus::ALL.index_with(&:itself), prefix: true, validate: true

  validates :status, inclusion: { in: CampusConstants::EnrollmentStatus::ALL }
  validates :user_id, uniqueness: {
    scope: :school_class_id,
    conditions: -> { where(discarded_at: nil) }
  }
  validate :user_must_be_student
  validate :one_active_enrollment_per_student

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: CampusConstants::EnrollmentStatus::ACTIVE) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_school_class, ->(school_class_id) { where(school_class_id: school_class_id) if school_class_id.present? }
  scope :by_campus, ->(campus_id) {
    if campus_id.blank?
      all
    else
      joins(:school_class).where(school_classes: { campus_id: campus_id })
    end
  }
  scope :by_level, ->(level) {
    if level.blank?
      all
    else
      joins(:school_class).where(school_classes: { level: level })
    end
  }

  private

  def user_must_be_student
    return if user.blank?
    return if user.has_role?(IamConstants::Role::STUDENT)

    errors.add(:user_id, :must_be_student)
  end

  def one_active_enrollment_per_student
    return if user.blank?
    return unless status == CampusConstants::EnrollmentStatus::ACTIVE

    conflict = ClassEnrollment.active.where(user_id: user_id)
    conflict = conflict.where.not(id: id) if persisted?
    return unless conflict.exists?

    errors.add(:user_id, :already_enrolled)
  end
end
