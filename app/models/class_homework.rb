# app/models/class_homework.rb

class ClassHomework < ApplicationRecord
  belongs_to :school_class, inverse_of: :class_homeworks
  belongs_to :lesson

  validate :activity_keys_must_be_ordered_catalog_subset


  scope :recent, -> { order(created_at: :desc) }
  scope :by_school_class, ->(school_class_id) {
    where(school_class_id: school_class_id) if school_class_id.present?
  }
  scope :by_lesson, ->(lesson_id) { where(lesson_id: lesson_id) if lesson_id.present? }
  scope :by_campus, ->(campus_id) {
    if campus_id.blank?
      all
    else
      joins(:school_class).where(school_classes: { campus_id: campus_id })
    end
  }

  def activity_labels
    Array(activity_keys).map { |key| CampusConstants::HomeworkActivity::LABELS[key] || key }
  end

  private

  def activity_keys_must_be_ordered_catalog_subset
    keys = Array(activity_keys)

    unless keys.is_a?(Array) && keys.all? { |key| key.is_a?(String) }
      errors.add(:activity_keys, :invalid)
      return
    end

    if keys.empty?
      errors.add(:activity_keys, :blank)
      return
    end

    if keys.size != keys.uniq.size
      errors.add(:activity_keys, :duplicate)
      return
    end

    unknown = keys - CampusConstants::HomeworkActivity::ALL
    return if unknown.empty?

    errors.add(:activity_keys, :unknown_keys)
  end
end
