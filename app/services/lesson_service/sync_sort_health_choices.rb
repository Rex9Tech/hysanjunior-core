# app/services/lesson_service/sync_sort_health_choices.rb

module LessonService
  class SyncSortHealthChoices
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
        choice = upsert_choice!(item, position: index)
        sync_items!(choice, item[:items])
        kept_ids << choice.id
      end

      @lesson.sort_health_choices.where.not(id: kept_ids).find_each(&:destroy!)
      @lesson.sort_health_choices.reload
      @lesson
    end

    private

    def normalize_item(item)
      data = item.to_h.deep_symbolize_keys
      {
        id: data[:id],
        label: data[:label],
        items: Array(data[:items]).map { |row| normalize_vocab_item(row) }
      }
    end

    def normalize_vocab_item(item)
      data = item.to_h.deep_symbolize_keys
      {
        id: data[:id],
        vocab: data[:vocab],
        image_asset_id: data[:image_asset_id],
        image: data[:image]
      }
    end

    def upsert_choice!(item, position:)
      label = item[:label].to_s.strip
      if label.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SORT_HEALTH_CHOICE_LABEL_REQUIRED)
      end

      attributes = { label: label, position: position }

      if item[:id].present?
        choice = @lesson.sort_health_choices.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::SORT_HEALTH_CHOICE_NOT_FOUND) if choice.blank?

        choice.update!(attributes)
        choice
      else
        @lesson.sort_health_choices.create!(attributes)
      end
    end

    def sync_items!(choice, items)
      kept_ids = []

      items.each_with_index do |item, index|
        vocabulary = upsert_vocab!(choice, item, position: index)
        LessonService::AttachVocabularyImage.call(
          vocabulary: vocabulary,
          image_asset_id: item[:image_asset_id],
          image: item[:image],
          created_by: @created_by,
          error_class: Error
        )
        kept_ids << vocabulary.id
      end

      choice.vocabularies.where.not(id: kept_ids).find_each(&:destroy!)
      choice.vocabularies.reload
    end

    def upsert_vocab!(choice, item, position:)
      vocab_text = item[:vocab].to_s.strip
      if vocab_text.blank?
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_REQUIRED)
      end

      attributes = {
        lesson_id: @lesson.id,
        sort_health_choice_id: choice.id,
        vocab: vocab_text,
        vowel_symbol: nil,
        position: position
      }

      if item[:id].present?
        vocabulary = choice.vocabularies.find_by(id: item[:id])
        raise Error, MessageService::Lesson.t(MessageService::Lesson::VOCAB_NOT_FOUND) if vocabulary.blank?

        vocabulary.update!(attributes)
        vocabulary
      else
        choice.vocabularies.create!(attributes)
      end
    end
  end
end
