# app/models/question.rb

class Question < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :questionable, polymorphic: true
  has_many :options, -> { ordered }, class_name: "QuestionOption", dependent: :destroy, inverse_of: :question

  # ===== VALIDATIONS =====
  validates :title, presence: true
  validates :kind, presence: true, inclusion: { in: QuestionConstants::Kind::ALL }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # ===== SCOPES =====
  scope :ordered, -> { order(:position, :created_at) }

  def ready?
    title.present? &&
      options.size >= QuestionConstants::Option::MIN_COUNT &&
      options.all? { |option| option.text.to_s.strip.present? } &&
      options.any?(&:correct?)
  end
end
