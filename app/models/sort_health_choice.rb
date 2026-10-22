# app/models/sort_health_choice.rb

class SortHealthChoice < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :lesson
  has_many :vocabularies, -> { ordered }, dependent: :destroy, inverse_of: :sort_health_choice

  # ===== VALIDATIONS =====
  validates :label, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # ===== SCOPES =====
  scope :ordered, -> { order(:position, :created_at) }

  def ready?
    label.to_s.strip.present? && vocabularies.any? { |row| row.vocab.to_s.strip.present? }
  end
end
