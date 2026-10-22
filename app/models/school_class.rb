# app/models/school_class.rb

class SchoolClass < ApplicationRecord
  belongs_to :campus, inverse_of: :school_classes
  has_many :class_enrollments, dependent: :destroy, inverse_of: :school_class
  has_many :students, through: :class_enrollments, source: :user
  has_many :class_assignments, dependent: :destroy, inverse_of: :school_class
  has_many :teachers, through: :class_assignments, source: :user
  has_many :class_homeworks, dependent: :destroy, inverse_of: :school_class


  enum :status, CampusConstants::Status::ALL.index_with(&:itself), prefix: true, validate: true

  validates :name, presence: true
  validates :level, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: CampusConstants::Level::MIN
  }
  validates :status, inclusion: { in: CampusConstants::Status::ALL }
  validates :name, uniqueness: {
    scope: [ :campus_id, :level ],
    case_sensitive: false,
    conditions: -> { where(discarded_at: nil) }
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_level, ->(level) { where(level: level) if level.present? }
  scope :by_campus, ->(campus_id) { where(campus_id: campus_id) if campus_id.present? }
  scope :search_term, ->(term) {
    if term.blank?
      all
    else
      q = "%#{term}%"
      where("name ILIKE :q", q: q)
    end
  }
end
