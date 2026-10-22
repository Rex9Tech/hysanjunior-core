# app/models/parent_student.rb

class ParentStudent < ApplicationRecord
  belongs_to :parent, class_name: "User"
  belongs_to :student, class_name: "User"

  validates :parent_id, uniqueness: {
    scope: :student_id,
    conditions: -> { where(discarded_at: nil) }
  }
  validate :parent_must_have_parent_role
  validate :student_must_have_student_role
  validate :parent_and_student_must_differ

  scope :recent, -> { order(created_at: :desc) }
  scope :by_parent, ->(parent_id) { where(parent_id: parent_id) if parent_id.present? }
  scope :by_student, ->(student_id) { where(student_id: student_id) if student_id.present? }

  private

  def parent_must_have_parent_role
    return if parent.blank?
    return if parent.has_role?(IamConstants::Role::PARENT)

    errors.add(:parent_id, :must_be_parent)
  end

  def student_must_have_student_role
    return if student.blank?
    return if student.has_role?(IamConstants::Role::STUDENT)

    errors.add(:student_id, :must_be_student)
  end

  def parent_and_student_must_differ
    return if parent_id.blank? || student_id.blank?
    return if parent_id != student_id

    errors.add(:student_id, :must_differ_from_parent)
  end
end
