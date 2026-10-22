# app/services/lesson_service/sync_vocabularies.rb

module LessonService
  class SyncVocabularies
    class Error < StandardError; end

    class << self
      def call(lesson, items:, created_by: nil)
        new(lesson, items:, created_by:).call
      end
    end

    def initialize(lesson, items:, created_by:)
      @lesson = lesson
      @items = Array(items).map { |item| normalize_item(item) }
      @created_by = created_by
    end

    def call
      kept_ids = []

      @items.each_with_index do |item, index|
        vocabulary = upsert_row!(item, position: index)
        LessonService::AttachVocabularyImage.call(
          vocabulary: vocabulary,
          image_asset_id: item[:image_asset_id],
          image: item[:image],
          created_by: @created_by,
          error_class: Error
        )
        kept_ids << vocabulary.id
      end

      list_scope.where.not(id: kept_ids).find_each(&:destroy!)
      @lesson.vocabularies.reload
      @lesson
    end

    private

    def list_scope
      @lesson.vocabularies.for_lesson_list
    end

    def normalize_item(item)
      {
        id: item[:id],
        vocab: item[:vocab],
        vowel_symbol: item[:vowel_symbol],
        image_asset_id: item[:image_asset_id],
        image: item[:image]
      }
    end

    def upsert_row!(item, position:)
      vocab_text = item[:vocab].to_s.strip
      if vocab_text.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_REQUIRED)
      end

      attributes = {
        vocab: vocab_text,
        vowel_symbol: item[:vowel_symbol].presence,
        position: position,
        sort_health_choice_id: nil
      }

      if item[:id].present?
        vocabulary = list_scope.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_NOT_FOUND) if vocabulary.blank?

        vocabulary.update!(attributes)
        vocabulary
      else
        list_scope.create!(attributes)
      end
    end
  end
end
