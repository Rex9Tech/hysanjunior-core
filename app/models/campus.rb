# app/models/campus.rb

class Campus < ApplicationRecord
  has_many :school_classes, dependent: :destroy, inverse_of: :campus
  has_many :campus_memberships, dependent: :destroy, inverse_of: :campus
  has_many :teachers, through: :campus_memberships, source: :user
  has_many :class_enrollments, through: :school_classes
  has_many :students, through: :class_enrollments, source: :user

  enum :status, CampusConstants::Status::ALL.index_with(&:itself), prefix: true, validate: true

  validates :name, presence: true
  validates :code, uniqueness: {
    case_sensitive: false,
    allow_nil: true,
    conditions: -> { where(discarded_at: nil) }
  }
  validates :status, inclusion: { in: CampusConstants::Status::ALL }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :search_term, ->(term) {
    if term.blank?
      all
    else
      q = "%#{term}%"
      where("name ILIKE :q OR code ILIKE :q", q: q)
    end
  }

  def active_students
    User.joins(class_enrollments: :school_class)
        .where(school_classes: { campus_id: id })
        .where(class_enrollments: { status: CampusConstants::EnrollmentStatus::ACTIVE })
        .distinct
  end
end
