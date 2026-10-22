# app/models/lesson.rb

class Lesson < ApplicationRecord
  # ===== ASSOCIATIONS =====
  has_many :assets, as: :assetable, dependent: :nullify
  has_many :vocabularies, -> { for_lesson_list.ordered }, dependent: :destroy, inverse_of: :lesson
  has_many :word_families, -> { ordered }, dependent: :destroy, inverse_of: :lesson
  has_many :questions, -> { ordered }, as: :questionable, dependent: :destroy, inverse_of: :questionable
  has_many :sort_health_choices, -> { ordered }, dependent: :destroy, inverse_of: :lesson
  has_many :class_homeworks, dependent: :restrict_with_error

  # ===== ENUMS =====
  enum :status, LessonConstants::Status::ALL.index_with(&:itself), prefix: true, validate: true

  # ===== VALIDATIONS =====
  validates :title, presence: true
  validates :unit, presence: true
  validates :level, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: LessonConstants::Level::MIN
  }
  validates :status, inclusion: { in: LessonConstants::Status::ALL }
  validate :story_order_must_be_string_array
  validate :build_the_sentences_must_be_pair_array
  validate :media_required_when_published

  # ===== SCOPES =====
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_level, ->(level) { where(level: level) if level.present? }
  scope :by_unit, ->(unit) { where(unit: unit) if unit.present? }
  scope :search_term, ->(term) {
    if term.blank?
      all
    else
      q = "%#{term}%"
      where("title ILIKE :q OR unit ILIKE :q", q: q)
    end
  }

  def song
    assets.find_by(
      format: AssetConstants::AssetFormat::AUDIO,
      parent_asset_id: nil
    )
  end

  def song_asset_id
    song&.id
  end

  def song_ready?
    song.present? && song.subtitles.exists?
  end

  def story
    assets.find_by(
      format: AssetConstants::AssetFormat::VIDEO,
      parent_asset_id: nil
    )
  end

  def story_asset_id
    story&.id
  end

  def story_ready?
    story.present? && story.subtitles.exists?
  end

  def vocabularies_ready?
    vocabularies.any? && vocabularies.all?(&:image_ready?)
  end

  def word_families_ready?
    word_families.any?(&:ready?)
  end

  def story_order_ready?
    Array(story_order).map { |line| line.to_s.strip }.reject(&:blank?).any?
  end

  def build_the_sentences_ready?
    pairs = normalized_build_the_sentences
    return false if pairs.blank?
    return false if pairs.size != vocabularies.size

    pairs.all? { |pair| pair[:vocab].present? && pair[:sentence].present? }
  end

  def questions_ready?
    questions.any?(&:ready?)
  end

  def sort_health_choices_ready?
    sort_health_choices.any?(&:ready?)
  end

  def normalized_build_the_sentences
    Array(build_the_sentences).filter_map do |row|
      data = row.is_a?(Hash) ? row.stringify_keys : {}
      vocab = data["vocab"].to_s.strip
      sentence = data["sentence"].to_s.strip
      next if vocab.blank? && sentence.blank?

      { vocab: vocab, sentence: sentence }
    end
  end

  private

  def story_order_must_be_string_array
    unless story_order.is_a?(Array) && story_order.all? { |line| line.is_a?(String) || line.is_a?(Numeric) }
      errors.add(:story_order, :invalid)
    end
  end

  def build_the_sentences_must_be_pair_array
    unless build_the_sentences.is_a?(Array) &&
           build_the_sentences.all? { |row| row.is_a?(Hash) }
      errors.add(:build_the_sentences, :invalid)
    end
  end

  def media_required_when_published
    return unless status == LessonConstants::Status::PUBLISHED

    unless song_ready?
      errors.add(:base, :song_required_for_publish)
    end

    unless story_ready?
      errors.add(:base, :story_required_for_publish)
    end

    unless vocabularies_ready?
      errors.add(:base, :vocabularies_required_for_publish)
    end

    unless word_families_ready?
      errors.add(:base, :word_families_required_for_publish)
    end

    unless story_order_ready?
      errors.add(:base, :story_order_required_for_publish)
    end

    unless build_the_sentences_ready?
      errors.add(:base, :build_the_sentences_required_for_publish)
    end

    unless questions_ready?
      errors.add(:base, :questions_required_for_publish)
    end

    unless sort_health_choices_ready?
      errors.add(:base, :sort_health_choices_required_for_publish)
    end
  end
end
