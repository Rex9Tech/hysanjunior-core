# app/models/vocabulary.rb

class Vocabulary < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :lesson
  belongs_to :sort_health_choice, optional: true
  has_many :assets, as: :assetable, dependent: :nullify

  # ===== VALIDATIONS =====
  validates :vocab, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # ===== SCOPES =====
  scope :ordered, -> { order(:position, :created_at) }
  scope :for_lesson_list, -> { where(sort_health_choice_id: nil) }
  scope :for_sort_health_choices, -> { where.not(sort_health_choice_id: nil) }

  def image
    assets.find_by(
      format: AssetConstants::AssetFormat::IMAGE,
      parent_asset_id: nil
    )
  end

  def image_asset_id
    image&.id
  end

  def image_ready?
    image.present?
  end

  def lesson_list?
    sort_health_choice_id.blank?
  end
end
