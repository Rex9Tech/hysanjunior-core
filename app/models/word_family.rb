# app/models/word_family.rb

class WordFamily < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :lesson

  # ===== VALIDATIONS =====
  validates :pattern, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :words_must_be_string_array

  # ===== SCOPES =====
  scope :ordered, -> { order(:position, :created_at) }

  def ready?
    pattern.present? && Array(words).map(&:to_s).map(&:strip).reject(&:blank?).any?
  end

  private

  def words_must_be_string_array
    unless words.is_a?(Array) && words.all? { |word| word.is_a?(String) || word.is_a?(Numeric) }
      errors.add(:words, :invalid)
    end
  end
end
