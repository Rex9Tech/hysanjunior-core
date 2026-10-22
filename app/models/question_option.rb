# app/models/question_option.rb

class QuestionOption < ApplicationRecord
  # ===== ASSOCIATIONS =====
  belongs_to :question
  has_many :assets, as: :assetable, dependent: :nullify

  # ===== VALIDATIONS =====
  validates :text, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :correct, inclusion: { in: [ true, false ] }

  # ===== SCOPES =====
  scope :ordered, -> { order(:position, :created_at) }

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
end
